// Test PGlite de la publication en deux temps (TAB-41 A2) : l'auteur insère un
// moment `statut='brouillon'` avec ses photos, le passe à `publie`, le supprime ;
// un tiers ne voit jamais le brouillon. Rejoue toutes les migrations avec de
// faux éléments Supabase, puis teste accès permis et refusés.
//
//   npm install --prefix /tmp/tabl-pglite @electric-sql/pglite
//   node scripts/tester_brouillon_pglite.mjs
//
// PGLITE_DIR change le dossier où PGlite est installé (défaut /tmp/tabl-pglite).
// Ne touche jamais à la vraie base : tout vit en mémoire.

import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { readdirSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import assert from 'node:assert/strict';

const dossierPglite = process.env.PGLITE_DIR ?? '/tmp/tabl-pglite';
const charger = createRequire(join(dossierPglite, 'package.json'));
const { PGlite } = charger('@electric-sql/pglite');
const { unaccent } = charger('@electric-sql/pglite/contrib/unaccent');
const { pg_trgm } = charger('@electric-sql/pglite/contrib/pg_trgm');

const racine = join(dirname(fileURLToPath(import.meta.url)), '..');
const dossierMigrations = join(racine, 'supabase', 'migrations');

const db = new PGlite({ extensions: { unaccent, pg_trgm } });

// ------------------------------------------------------------
//  Faux Supabase
// ------------------------------------------------------------
await db.exec(`
  create role anon nologin;
  create role authenticated nologin;
  create role service_role nologin bypassrls;
  create schema extensions;
  create schema auth;
  create schema storage;
  grant usage on schema public, extensions to anon, authenticated, service_role;
  grant usage on schema auth, storage to anon, authenticated, service_role;

  create table auth.users (id uuid primary key, email text);

  create function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
  $$;
  grant execute on function auth.uid() to anon, authenticated, service_role;

  create table storage.buckets (
    id text primary key, name text, public boolean default false,
    file_size_limit bigint, allowed_mime_types text[]
  );
  create table storage.objects (
    id uuid primary key default gen_random_uuid(),
    bucket_id text, name text, owner uuid default auth.uid()
  );
  alter table storage.objects enable row level security;
  grant select, insert, update, delete on storage.objects to authenticated;
  create function storage.foldername(name text) returns text[]
    language sql immutable as $$ select string_to_array(name, '/') $$;
`);
const migrations = readdirSync(dossierMigrations).filter((f) => f.endsWith('.sql')).sort();
for (const f of migrations) {
  try {
    await db.exec(readFileSync(join(dossierMigrations, f), 'utf8'));
  } catch (e) {
    console.error(`Migration en échec : ${f}\n  ${e.message}`);
    process.exit(2);
  }
}
console.log(`${migrations.length} migrations rejouées.`);

// ------------------------------------------------------------
//  Outils de test
// ------------------------------------------------------------
async function en(role, uid, sql, params = []) {
  await db.exec(`set role ${role}`);
  try {
    await db.query(`select set_config('request.jwt.claim.sub', $1, false)`, [uid ?? '']);
    try {
      const r = await db.query(sql, params);
      return { ok: true, rows: r.rows, nb: r.affectedRows ?? r.rows.length };
    } catch (e) {
      return { ok: false, code: e.code, message: e.message };
    }
  } finally {
    await db.exec('reset role');
  }
}
const lu = (uid, sql, params) => en('authenticated', uid, sql, params);

let nbTests = 0;
async function test(nom, f) {
  try {
    await f();
    nbTests++;
    console.log(`  ok   ${nom}`);
  } catch (e) {
    console.error(`  ECHEC ${nom}\n        ${e.message}`);
    process.exitCode = 1;
  }
}
const refuse = (r, code) => {
  assert.equal(r.ok, false, `devait être refusé, a réussi : ${JSON.stringify(r.rows)}`);
  if (code) assert.equal(r.code, code, `code ${r.code} (${r.message})`);
};
const reussit = (r) => assert.equal(r.ok, true, `${r.code} ${r.message}`);
// Une écriture que la RLS ne laisse pas voir : pas d'erreur, zéro ligne touchée.
const zeroLigne = (r) => {
  reussit(r);
  assert.equal(r.nb, 0, `devait toucher 0 ligne, en a touché ${r.nb}`);
};

// ------------------------------------------------------------
//  Personnes et lieux (créés en superutilisateur)
// ------------------------------------------------------------
const id = (n) => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const AUTEUR = id(1);
const ABONNE = id(2); // abonnement accepté
const ETRANGER = id(3); // aucun lien
const NOMME = id(4); // nommé dans une audience « seulement »
const EXCLU = id(5); // exclu d'une audience « sauf », pourtant abonné
const MEMBRE = id(6); // membre actif d'une Table, sans abonnement
const RESTO = id(100); // restaurant des moments publiés
const RESTO_NEUF = id(101); // restaurant qui n'a que des brouillons
const TABLE = id(300);

for (const [n, pseudo] of [[1, 'auteur'], [2, 'abonne'], [3, 'etranger'], [4, 'nomme'], [5, 'exclu'], [6, 'membre']]) {
  await db.query(`insert into auth.users (id, email) values ($1, $2)`, [id(n), `${pseudo}@test.fr`]);
  await db.query(`insert into public.profils (id, pseudo) values ($1, $2) on conflict do nothing`, [id(n), pseudo]);
}
await db.query(
  `insert into public.restaurants (id, nom, ville, latitude, longitude, cree_par)
   values ($1, 'Chez Test', 'Liège', 50.64, 5.57, $3), ($2, 'Nouveau Lieu', 'Liège', 50.65, 5.58, $3)`,
  [RESTO, RESTO_NEUF, AUTEUR],
);
for (const suiveur of [ABONNE, EXCLU]) {
  await db.query(
    `insert into public.abonnements (suiveur_id, suivi_id, statut) values ($1, $2, 'accepte')`,
    [suiveur, AUTEUR],
  );
}
await db.query(`insert into public.tables (id, nom, cree_par) values ($1, 'Notre table', $2)`, [TABLE, AUTEUR]);
await db.query(
  `insert into public.membres_table (table_id, profil_id, statut, est_admin)
   values ($1, $2, 'active', true), ($1, $3, 'active', false)`,
  [TABLE, AUTEUR, MEMBRE],
);

// ------------------------------------------------------------
//  Le flux de l'app, geste par geste (souvenir_service_supabase.dart)
// ------------------------------------------------------------
const TIERS = [
  [ABONNE, 'abonné accepté'],
  [ETRANGER, 'étranger'],
  [NOMME, 'personne nommée dans l’audience'],
  [EXCLU, 'abonné exclu de l’audience'],
  [MEMBRE, 'membre actif de la Table associée'],
];
const cheminsDe = (uid, n) => Array.from({ length: n }, (_, i) => `${uid}/${1700000000000 + n}-${i}.jpg`);

// Étape 1 : dépôt des photos dans son dossier, puis insertion du brouillon et
// de ses lignes liées. `visibilite` suit le choix d'audience.
async function etape1(uid, idm, { photos = 3, visibilite = 'seulement', resto = RESTO, personnes = [NOMME], table = true } = {}) {
  const chemins = cheminsDe(uid, photos);
  for (const c of chemins) {
    reussit(await lu(uid, `insert into storage.objects (bucket_id, name) values ('souvenirs', $1)`, [c]));
  }
  reussit(await lu(
    uid,
    `insert into public.souvenirs (id, auteur_id, restaurant_id, photo_url, statut, visibilite, emotion, legende, moment, date_visite)
     values ($1, $2, $3, $4, 'brouillon', $5, '😍', 'Une belle table', 'midi', current_date)`,
    [idm, uid, resto, chemins[0] ?? null, visibilite],
  ));
  for (let rang = 1; rang < chemins.length; rang++) {
    reussit(await lu(uid, `insert into public.souvenirs_photos (souvenir_id, rang, chemin) values ($1, $2, $3)`, [idm, rang, chemins[rang]]));
  }
  reussit(await lu(uid, `insert into public.souvenirs_empreintes (souvenir_id, empreinte) values ($1, 'abc123')`, [idm]));
  reussit(await lu(uid, `insert into public.souvenirs_amis_tagues (souvenir_id, profil_id) values ($1, $2)`, [idm, ABONNE]));
  for (const p of personnes) {
    reussit(await lu(uid, `insert into public.souvenirs_audience (souvenir_id, profil_id) values ($1, $2)`, [idm, p]));
  }
  if (table) {
    reussit(await lu(uid, `insert into public.associations_experience_table (souvenir_id, table_id, ajoute_par) values ($1, $2, $3)`, [idm, TABLE, uid]));
  }
  return chemins;
}

const M = { flux: id(201), autrui: id(202), annule: id(203), sans_photo: id(204) };

console.log('\nÉtape 1 — l’auteur dépose ses photos et insère le brouillon');
let chemins;
await test('dépôt des photos, insertion en brouillon, photos 2 à 10, empreintes, amis tagués, audience, Table', async () => {
  chemins = await etape1(AUTEUR, M.flux);
});
await test('l’auteur relit son brouillon (le .select(\'id\') qui suit l’insertion)', async () => {
  const r = await lu(AUTEUR, `select id, statut, photo_url from public.souvenirs where id = $1`, [M.flux]);
  reussit(r);
  assert.deepEqual(r.rows, [{ id: M.flux, statut: 'brouillon', photo_url: chemins[0] }]);
});
await test('l’auteur relit aussi les lignes liées du brouillon (photos, empreintes, audience, amis tagués)', async () => {
  for (const [table, attendu] of [
    ['souvenirs_photos', 2], ['souvenirs_empreintes', 1], ['souvenirs_audience', 1], ['souvenirs_amis_tagues', 1],
  ]) {
    const r = await lu(AUTEUR, `select count(*)::int as n from public.${table} where souvenir_id = $1`, [M.flux]);
    reussit(r);
    assert.equal(r.rows[0].n, attendu, table);
  }
});
await test('l’auteur relit les fichiers déposés (repli « propre dossier » avant publication)', async () => {
  const r = await lu(AUTEUR, `select count(*)::int as n from storage.objects where bucket_id = 'souvenirs' and name = any($1)`, [chemins]);
  reussit(r);
  assert.equal(r.rows[0].n, 3);
});
await test('l’auteur retrouve ses brouillons orphelins (réconciliation au lancement)', async () => {
  const r = await lu(AUTEUR, `select id from public.souvenirs where auteur_id = $1 and statut = 'brouillon'`, [AUTEUR]);
  reussit(r);
  assert.deepEqual(r.rows, [{ id: M.flux }]);
});
await test('l’id généré sur le téléphone sert de clé d’idempotence : le doublon est refusé (23505)', async () => {
  refuse(
    await lu(AUTEUR, `insert into public.souvenirs (id, auteur_id, restaurant_id, statut) values ($1, $2, $3, 'brouillon')`, [M.flux, AUTEUR, RESTO]),
    '23505',
  );
  const r = await lu(AUTEUR, `select count(*)::int as n from public.souvenirs where id = $1`, [M.flux]);
  assert.equal(r.rows[0].n, 1);
});
await test('un brouillon sans photo (« Sans photo ») est accepté tant que ce n’est pas un souvenir du passé', async () => {
  reussit(await lu(
    AUTEUR,
    `insert into public.souvenirs (id, auteur_id, restaurant_id, statut) values ($1, $2, $3, 'brouillon')`,
    [M.sans_photo, AUTEUR, RESTO],
  ));
  refuse(await lu(AUTEUR, `update public.souvenirs set est_souvenir = true where id = $1`, [M.sans_photo]), '23514');
  await db.query(`delete from public.souvenirs where id = $1`, [M.sans_photo]);
});
await test('on ne peut pas insérer un brouillon au nom d’un autre (42501)', async () => {
  refuse(
    await lu(ABONNE, `insert into public.souvenirs (auteur_id, restaurant_id, statut) values ($1, $2, 'brouillon')`, [AUTEUR, RESTO]),
    '42501',
  );
});
await test('on ne dépose pas de photo dans le dossier d’un autre (42501)', async () => {
  refuse(await lu(ABONNE, `insert into storage.objects (bucket_id, name) values ('souvenirs', $1)`, [`${AUTEUR}/intrus.jpg`]), '42501');
});
await test('on ne peut pas attacher de photo ni d’audience au brouillon d’un autre', async () => {
  refuse(await lu(ABONNE, `insert into public.souvenirs_photos (souvenir_id, rang, chemin) values ($1, 5, 'x')`, [M.flux]), '42501');
  refuse(await lu(ABONNE, `insert into public.souvenirs_audience (souvenir_id, profil_id) values ($1, $2)`, [M.flux, ABONNE]), '42501');
  refuse(await lu(ABONNE, `insert into public.souvenirs_empreintes (souvenir_id, empreinte) values ($1, 'x')`, [M.flux]), '42501');
});
await test('un statut inconnu est refusé (23514)', async () => {
  refuse(await lu(AUTEUR, `update public.souvenirs set statut = 'archive' where id = $1`, [M.flux]), '23514');
});

console.log('\nLe brouillon reste invisible pour tout tiers');
for (const [qui, raison] of TIERS) {
  await test(`${raison} : ne lit ni le moment, ni ses photos, ni ses lignes liées`, async () => {
    const m = await lu(qui, `select id from public.souvenirs where id = $1`, [M.flux]);
    reussit(m);
    assert.deepEqual(m.rows, []);
    const p = await lu(qui, `select public.peut_voir_souvenir($1) as v`, [M.flux]);
    assert.equal(p.rows[0].v, false);
    for (const t of ['souvenirs_photos', 'souvenirs_amis_tagues', 'souvenirs_audience', 'souvenirs_empreintes']) {
      const r = await lu(qui, `select count(*)::int as n from public.${t} where souvenir_id = $1`, [M.flux]);
      reussit(r);
      assert.equal(r.rows[0].n, 0, t);
    }
    const f = await lu(qui, `select count(*)::int as n from storage.objects where bucket_id = 'souvenirs' and name = any($1)`, [chemins]);
    reussit(f);
    assert.equal(f.rows[0].n, 0, 'fichiers du brouillon');
  });
}
await test('lecture en masse : aucun brouillon dans les moments d’un tiers', async () => {
  for (const [qui] of TIERS) {
    const r = await lu(qui, `select id from public.souvenirs where statut = 'brouillon'`);
    reussit(r);
    assert.deepEqual(r.rows, []);
  }
});
await test('un tiers ne peut ni réagir ni commenter un brouillon', async () => {
  refuse(await lu(ABONNE, `insert into public.reactions (souvenir_id, profil_id) values ($1, $2)`, [M.flux, ABONNE]), '42501');
  refuse(await lu(ABONNE, `insert into public.commentaires (souvenir_id, auteur_id, texte) values ($1, $2, 'coucou')`, [M.flux, ABONNE]), '42501');
});
await test('anon : aucun accès (42501)', async () => {
  refuse(await en('anon', null, `select id from public.souvenirs`), '42501');
  refuse(await en('anon', null, `select name from storage.objects`), '42501');
});
await test('compteurs_profil : le brouillon n’est pas compté dans les moments', async () => {
  for (const qui of [ABONNE, AUTEUR]) {
    const r = await lu(qui, `select moments from public.compteurs_profil($1)`, [AUTEUR]);
    reussit(r);
    assert.equal(r.rows[0].moments, 0, `vu par ${qui}`);
  }
});
await test('lieux_carte : un restaurant qui n’a qu’un brouillon n’apparaît pour personne, auteur compris', async () => {
  await db.query(`update public.souvenirs set restaurant_id = $2 where id = $1`, [M.flux, RESTO_NEUF]);
  // « Ma carte » pour l'auteur, « cercle » pour les autres : chacun dans le mode où il verrait le lieu.
  for (const [qui, mode] of [[AUTEUR, 'moi'], [ABONNE, 'cercle'], [ETRANGER, 'cercle']]) {
    const r = await lu(qui, `select restaurant_id, visites, mes_visites from public.lieux_carte(50, 5, 51, 6, p_mode => $1)`, [mode]);
    reussit(r);
    assert.deepEqual(r.rows.filter((l) => l.restaurant_id === RESTO_NEUF), [], `vu par ${qui}`);
  }
  await db.query(`update public.souvenirs set restaurant_id = $2 where id = $1`, [M.flux, RESTO]);
});

console.log('\nÉtape 2 — le commit : UPDATE statut = \'publie\'');
await test('un tiers ne peut pas publier le brouillon d’un autre : 0 ligne touchée, toujours brouillon', async () => {
  zeroLigne(await lu(ABONNE, `update public.souvenirs set statut = 'publie' where id = $1`, [M.flux]));
  const { rows } = await db.query(`select statut from public.souvenirs where id = $1`, [M.flux]);
  assert.equal(rows[0].statut, 'brouillon');
});
await test('l’auteur publie son brouillon (une seule colonne, comme l’app)', async () => {
  const r = await lu(AUTEUR, `update public.souvenirs set statut = 'publie' where id = $1 and statut = 'brouillon' returning id, statut`, [M.flux]);
  reussit(r);
  assert.deepEqual(r.rows, [{ id: M.flux, statut: 'publie' }]);
});
await test('le commit rejoué est sans effet : 0 ligne avec le filtre brouillon, toujours un seul moment publié', async () => {
  zeroLigne(await lu(AUTEUR, `update public.souvenirs set statut = 'publie' where id = $1 and statut = 'brouillon'`, [M.flux]));
  const r = await lu(AUTEUR, `select count(*)::int as n from public.souvenirs where id = $1 and statut = 'publie'`, [M.flux]);
  assert.equal(r.rows[0].n, 1);
});
await test('un moment publié ne se rejoue plus en insertion (23505) : pas de doublon après coupure', async () => {
  refuse(
    await lu(AUTEUR, `insert into public.souvenirs (id, auteur_id, restaurant_id, statut) values ($1, $2, $3, 'publie')`, [M.flux, AUTEUR, RESTO]),
    '23505',
  );
});
await test('un auteur ne peut pas confier son moment à un autre en changeant auteur_id (42501)', async () => {
  refuse(await lu(AUTEUR, `update public.souvenirs set auteur_id = $2 where id = $1`, [M.flux, ABONNE]), '42501');
});

console.log('\nAprès le commit, la visibilité suit « Qui peut voir ? » (audience « Seulement »)');
const apres = [
  [NOMME, true, 'personne nommée'],
  [MEMBRE, true, 'membre actif de la Table associée'],
  [ABONNE, false, 'abonné non nommé'],
  [ETRANGER, false, 'étranger'],
  [EXCLU, false, 'autre abonné non nommé'],
];
for (const [qui, visible, raison] of apres) {
  await test(`${raison} → moment ${visible ? 'lu' : 'invisible'}, photos ${visible ? 'lisibles' : 'illisibles'}`, async () => {
    const m = await lu(qui, `select id from public.souvenirs where id = $1`, [M.flux]);
    reussit(m);
    assert.deepEqual(m.rows, visible ? [{ id: M.flux }] : []);
    const f = await lu(qui, `select count(*)::int as n from storage.objects where bucket_id = 'souvenirs' and name = any($1)`, [chemins]);
    reussit(f);
    assert.equal(f.rows[0].n, visible ? 3 : 0);
  });
}
await test('en « Tout le monde », l’abonné accepté voit le moment publié (photos 2 à 10 comprises)', async () => {
  await db.query(`update public.souvenirs set visibilite = 'tout_le_monde' where id = $1`, [M.flux]);
  await db.query(`delete from public.associations_experience_table where souvenir_id = $1`, [M.flux]);
  const m = await lu(ABONNE, `select id from public.souvenirs where id = $1`, [M.flux]);
  assert.deepEqual(m.rows, [{ id: M.flux }]);
  const p = await lu(ABONNE, `select count(*)::int as n from public.souvenirs_photos where souvenir_id = $1`, [M.flux]);
  assert.equal(p.rows[0].n, 2);
  const f = await lu(ABONNE, `select count(*)::int as n from storage.objects where bucket_id = 'souvenirs' and name = any($1)`, [chemins]);
  assert.equal(f.rows[0].n, 3);
  const c = await lu(ABONNE, `select moments from public.compteurs_profil($1)`, [AUTEUR]);
  assert.equal(c.rows[0].moments, 1);
  const e = await lu(ETRANGER, `select id from public.souvenirs where id = $1`, [M.flux]);
  assert.deepEqual(e.rows, [], 'profil privé : l’étranger ne voit toujours pas');
});
await test('témoins : une fois publié, l’abonné peut réagir et commenter, et le lieu apparaît sur la carte', async () => {
  reussit(await lu(ABONNE, `insert into public.reactions (souvenir_id, profil_id) values ($1, $2)`, [M.flux, ABONNE]));
  reussit(await lu(ABONNE, `insert into public.commentaires (souvenir_id, auteur_id, texte) values ($1, $2, 'coucou')`, [M.flux, ABONNE]));
  const carte = await lu(ABONNE, `select visites from public.lieux_carte(50, 5, 51, 6) where restaurant_id = $1`, [RESTO]);
  reussit(carte);
  assert.equal(carte.rows.length, 1);
  const moi = await lu(AUTEUR, `select mes_visites from public.lieux_carte(50, 5, 51, 6, p_mode => 'moi') where restaurant_id = $1`, [RESTO]);
  assert.equal(moi.rows[0].mes_visites, 1);
});
await test('l’auteur compte une visite de plus (« n-ième fois ici ») seulement une fois publié', async () => {
  const r = await lu(AUTEUR, `select count(*)::int as n from public.souvenirs where auteur_id = $1 and restaurant_id = $2 and statut = 'publie'`, [AUTEUR, RESTO]);
  assert.equal(r.rows[0].n, 1);
});
await test('observation : l’auteur peut repasser un moment publié en brouillon (rien ne l’interdit) — l’app ne doit pas le faire', async () => {
  const r = await lu(AUTEUR, `update public.souvenirs set statut = 'brouillon' where id = $1 returning statut`, [M.flux]);
  reussit(r);
  assert.equal(r.rows[0].statut, 'brouillon');
  const e = await lu(ABONNE, `select id from public.souvenirs where id = $1`, [M.flux]);
  assert.deepEqual(e.rows, [], 'le tiers ne le voit plus pendant ce temps');
  await db.query(`update public.souvenirs set statut = 'publie' where id = $1`, [M.flux]);
});

console.log('\nÉtape 3 — annuler : suppression de la ligne puis des photos');
await test('un tiers ne peut pas supprimer le brouillon d’un autre : 0 ligne, brouillon intact', async () => {
  chemins.autrui = await etape1(AUTEUR, M.autrui, { photos: 2, visibilite: 'tout_le_monde', personnes: [], table: false });
  for (const [qui] of TIERS) {
    zeroLigne(await lu(qui, `delete from public.souvenirs where id = $1`, [M.autrui]));
  }
  const { rows } = await db.query(`select statut from public.souvenirs where id = $1`, [M.autrui]);
  assert.deepEqual(rows, [{ statut: 'brouillon' }]);
});
await test('un tiers ne peut pas supprimer les fichiers du brouillon d’un autre : 0 fichier effacé', async () => {
  zeroLigne(await lu(ABONNE, `delete from storage.objects where bucket_id = 'souvenirs' and name = any($1)`, [chemins.autrui]));
  const { rows } = await db.query(`select count(*)::int as n from storage.objects where name = any($1)`, [chemins.autrui]);
  assert.equal(rows[0].n, 2);
});
await test('l’auteur relève les chemins de ses fichiers avant de supprimer (comme supprimer() dans l’app)', async () => {
  const r = await lu(AUTEUR, `select photo_url, (select array_agg(chemin) from public.souvenirs_photos p where p.souvenir_id = s.id) as autres from public.souvenirs s where id = $1`, [M.autrui]);
  reussit(r);
  assert.equal(r.rows[0].photo_url, chemins.autrui[0]);
  assert.deepEqual(r.rows[0].autres, [chemins.autrui[1]]);
});
await test('l’auteur supprime son brouillon : la ligne et toutes ses lignes liées partent (cascade)', async () => {
  const r = await lu(AUTEUR, `delete from public.souvenirs where id = $1 returning id`, [M.autrui]);
  reussit(r);
  assert.deepEqual(r.rows, [{ id: M.autrui }]);
  for (const t of ['souvenirs_photos', 'souvenirs_empreintes', 'souvenirs_audience', 'souvenirs_amis_tagues', 'associations_experience_table']) {
    const { rows } = await db.query(`select count(*)::int as n from public.${t} where souvenir_id = $1`, [M.autrui]);
    assert.equal(rows[0].n, 0, t);
  }
});
await test('puis il efface ses fichiers dans son dossier', async () => {
  const r = await lu(AUTEUR, `delete from storage.objects where bucket_id = 'souvenirs' and name = any($1) returning name`, [chemins.autrui]);
  reussit(r);
  assert.equal(r.nb, 2);
});
await test('annulation avant tout fichier : la ligne seule se supprime aussi', async () => {
  reussit(await lu(AUTEUR, `insert into public.souvenirs (id, auteur_id, restaurant_id, statut) values ($1, $2, $3, 'brouillon')`, [M.annule, AUTEUR, RESTO]));
  const r = await lu(AUTEUR, `delete from public.souvenirs where id = $1 returning id`, [M.annule]);
  reussit(r);
  assert.equal(r.nb, 1);
});
await test('supprimer un moment déjà publié passe par les mêmes droits', async () => {
  const r = await lu(AUTEUR, `delete from public.souvenirs where id = $1 returning id`, [M.flux]);
  reussit(r);
  assert.equal(r.nb, 1);
  const f = await lu(AUTEUR, `delete from storage.objects where bucket_id = 'souvenirs' and name = any($1)`, [chemins]);
  assert.equal(f.nb, 3);
  const reste = await db.query(`select (select count(*)::int from public.souvenirs) as s, (select count(*)::int from storage.objects) as o`);
  assert.deepEqual(reste.rows, [{ s: 0, o: 0 }]);
});

console.log('\nSuppression de compte (service_role)');
await test('les brouillons partent avec le compte, comme les moments publiés', async () => {
  await etape1(AUTEUR, id(210), { photos: 1, personnes: [], table: false });
  const r = await en('service_role', null, `delete from public.souvenirs where auteur_id = $1`, [AUTEUR]);
  reussit(r);
  assert.equal(r.nb, 1);
});

console.log('\nRègle 42P17 et droits');
await test('aucune policy des tables du flux ne relit sa propre table', async () => {
  const { rows } = await db.query(
    `select tablename, policyname, coalesce(qual, '') || ' ' || coalesce(with_check, '') as expr
     from pg_policies
     where schemaname = 'public'
       and tablename in ('souvenirs', 'souvenirs_photos', 'souvenirs_audience', 'souvenirs_empreintes', 'souvenirs_amis_tagues', 'associations_experience_table')`,
  );
  assert.ok(rows.length >= 12, `policies introuvables (${rows.length})`);
  const fautives = rows.filter((p) => new RegExp(`\\b(from|join)\\s+(public\\.)?${p.tablename}\\b`, 'i').test(p.expr));
  assert.deepEqual(fautives, []);
});
await test('droits de table de souvenirs : insert, update (toute la table), delete — pas de grant par colonne à ajouter pour `statut`', async () => {
  const { rows } = await db.query(
    `select privilege_type from information_schema.role_table_grants
     where table_schema = 'public' and table_name = 'souvenirs' and grantee = 'authenticated'
     order by privilege_type`,
  );
  assert.deepEqual(rows.map((r) => r.privilege_type), ['DELETE', 'INSERT', 'SELECT', 'UPDATE']);
});

console.log(`\n${nbTests} tests passés${process.exitCode ? ' — AVEC ÉCHECS' : ''}.`);
await db.close();
