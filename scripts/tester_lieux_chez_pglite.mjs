// Test PGlite des lieux hors restaurant (chez moi, chez quelqu'un, ailleurs,
// migration 20261114000000_lieux_chez.sql) : rejoue toutes les migrations avec
// de faux éléments Supabase, puis teste accès permis et refusés.
//
//   npm install --prefix /tmp/tabl-pglite @electric-sql/pglite
//   node scripts/tester_lieux_chez_pglite.mjs
//
// PGLITE_DIR change le dossier où PGlite est installé (défaut /tmp/tabl-pglite).
// Ne touche jamais à la vraie base : tout vit en mémoire.

import { createRequire } from 'node:module';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { readdirSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import assert from 'node:assert/strict';

const dossierPglite = process.env.PGLITE_DIR ?? '/tmp/tabl-pglite';
const req = createRequire(join(dossierPglite, 'package.json'));
const charger = (spec) => import(pathToFileURL(req.resolve(spec)).href);
const { PGlite } = await charger('@electric-sql/pglite');
const { unaccent } = await charger('@electric-sql/pglite/contrib/unaccent');
const { pg_trgm } = await charger('@electric-sql/pglite/contrib/pg_trgm');

const racine = join(dirname(fileURLToPath(import.meta.url)), '..');
const dossierMigrations = join(racine, 'supabase', 'migrations');

const db = new PGlite({ extensions: { unaccent, pg_trgm } });

// ------------------------------------------------------------
//  Faux Supabase
// ------------------------------------------------------------
await db.exec(`
  create role anon nologin;
  create role authenticated nologin;
  create role service_role nologin;
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
    bucket_id text, name text, owner uuid
  );
  alter table storage.objects enable row level security;
  create function storage.foldername(name text) returns text[]
    language sql immutable as $$ select string_to_array(name, '/') $$;
`);
// unaccent / pg_trgm sont créés par les migrations (`create extension … with
// schema extensions`) : on laisse faire, sinon on les installe d'avance.
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

// ------------------------------------------------------------
//  Données (créées en superutilisateur)
// ------------------------------------------------------------
const id = (n) => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const AUTEUR = id(1);
const HOTE = id(2); // suivi par l'auteur, et le suit
const ETRANGER = id(3); // aucun lien
const NOMME = id(4); // abonné de l'auteur, nommé dans une audience « seulement »
const CHEZ_EMMA = id(100);
const CHEZ_MOI = id(101);
const M = { tous: id(201), brouillon: id(202), seulement: id(203), domicile: id(204) };

for (const [n, pseudo] of [[1, 'auteur'], [2, 'emma'], [3, 'etranger'], [4, 'nomme']]) {
  await db.query(`insert into auth.users (id, email) values ($1, $2)`, [id(n), `${pseudo}@test.fr`]);
  await db.query(`insert into public.profils (id, pseudo) values ($1, $2) on conflict do nothing`, [id(n), pseudo]);
}
for (const [suiveur, suivi] of [[AUTEUR, HOTE], [HOTE, AUTEUR], [NOMME, AUTEUR]]) {
  await db.query(
    `insert into public.abonnements (suiveur_id, suivi_id, statut) values ($1, $2, 'accepte')`,
    [suiveur, suivi],
  );
}
await db.query(
  `insert into public.restaurants (id, nom, ville, cree_par, prive, genre, hote_id)
   values ($1, 'Chez quelqu''un', '', $2, true, 'chez', $3),
          ($4, 'Chez moi', '', $2, true, 'domicile', null)`,
  [CHEZ_EMMA, AUTEUR, HOTE, CHEZ_MOI],
);
async function moment(idm, lieu, { statut = 'publie', visibilite = 'tout_le_monde' } = {}) {
  await db.query(
    `insert into public.souvenirs (id, auteur_id, restaurant_id, statut, visibilite)
     values ($1, $2, $3, $4, $5)`,
    [idm, AUTEUR, lieu, statut, visibilite],
  );
}
await moment(M.tous, CHEZ_EMMA);
await moment(M.brouillon, CHEZ_EMMA, { statut: 'brouillon' });
await moment(M.seulement, CHEZ_EMMA, { visibilite: 'seulement' });
await moment(M.domicile, CHEZ_MOI);
await db.query(`insert into public.souvenirs_audience (souvenir_id, profil_id) values ($1, $2)`, [M.seulement, NOMME]);

// ------------------------------------------------------------
//  Tests
// ------------------------------------------------------------
console.log('\nContraintes : jamais de position hors restaurant');
await test('un genre sur un restaurant public est refusé', async () => {
  const r = await en('postgres', null,
    `insert into public.restaurants (nom, ville, cree_par, genre) values ('Bibo', 'Liège', $1, 'chez')`, [AUTEUR]);
  refuse(r, '23514');
});
await test('« Chez moi » avec une position est refusé', async () => {
  const r = await en('postgres', null,
    `insert into public.restaurants (nom, ville, cree_par, prive, genre, latitude, longitude)
     values ('Chez moi', '', $1, true, 'domicile', 50.6, 5.5)`, [AUTEUR]);
  refuse(r, '23514');
});
await test('un genre inconnu est refusé', async () => {
  const r = await en('postgres', null,
    `insert into public.restaurants (nom, ville, cree_par, prive, genre) values ('X', '', $1, true, 'bureau')`, [AUTEUR]);
  refuse(r, '23514');
});
await test('un hôte hors de « chez » est refusé', async () => {
  const r = await en('postgres', null,
    `insert into public.restaurants (nom, ville, cree_par, prive, genre, hote_id)
     values ('Pique-nique', '', $1, true, 'ailleurs', $2)`, [AUTEUR, HOTE]);
  refuse(r, '23514');
});
await test('être son propre hôte est refusé', async () => {
  const r = await en('postgres', null,
    `insert into public.restaurants (nom, ville, cree_par, prive, genre, hote_id)
     values ('Chez quelqu''un', '', $1, true, 'chez', $1)`, [AUTEUR]);
  refuse(r, '23514');
});

console.log("\nCréer (comme l'app)");
await test('« Chez moi » : permis', async () => {
  reussit(await lu(AUTEUR,
    `insert into public.restaurants (nom, ville, nom_recherche, cree_par, prive, genre)
     values ('Chez moi', '', 'chez moi', $1, true, 'domicile')`, [AUTEUR]));
});
await test('chez quelqu’un que je suis : permis', async () => {
  reussit(await lu(AUTEUR,
    `insert into public.restaurants (nom, ville, nom_recherche, cree_par, prive, genre, hote_id)
     values ('Chez quelqu''un', '', 'chez quelqu''un', $1, true, 'chez', $2)`, [AUTEUR, HOTE]));
});
await test('chez un inconnu : refusé', async () => {
  refuse(await lu(AUTEUR,
    `insert into public.restaurants (nom, ville, nom_recherche, cree_par, prive, genre, hote_id)
     values ('Chez quelqu''un', '', 'chez quelqu''un', $1, true, 'chez', $2)`, [AUTEUR, ETRANGER]), '42501');
});
await test('« Pique-nique » sans hôte : permis', async () => {
  reussit(await lu(AUTEUR,
    `insert into public.restaurants (nom, ville, nom_recherche, cree_par, prive, genre)
     values ('Pique-nique', '', 'pique-nique', $1, true, 'ailleurs')`, [AUTEUR]));
});

console.log('\nLire');
await test("l'hôte lit le lieu qui le cite", async () => {
  const r = await lu(HOTE, `select genre, hote_id from public.restaurants where id = $1`, [CHEZ_EMMA]);
  reussit(r);
  assert.deepEqual(r.rows, [{ genre: 'chez', hote_id: HOTE }]);
});
await test('un inconnu ne lit pas « Chez moi » (aucun moment visible)', async () => {
  const r = await lu(ETRANGER, `select id from public.restaurants where id = $1`, [CHEZ_MOI]);
  reussit(r);
  assert.equal(r.rows.length, 0);
});

console.log('\nNotifications « chez vous »');
const notifs = async (uid) => {
  const r = await lu(uid, `select type, souvenir_id, restaurant_genre from public.mes_notifications()`);
  reussit(r);
  return r.rows;
};
await test("l'hôte est prévenu du moment publié, pas du brouillon", async () => {
  const chez = (await notifs(HOTE)).filter((n) => n.type === 'chez_vous');
  assert.deepEqual(chez.map((n) => n.souvenir_id), [M.tous]);
  assert.equal(chez[0].restaurant_genre, 'chez');
});
await test("hors de l'audience (« seulement » sans lui) : rien", async () => {
  const chez = (await notifs(HOTE)).filter((n) => n.souvenir_id === M.seulement);
  assert.equal(chez.length, 0);
});
await test('le genre accompagne les autres notifications (j’aime chez moi)', async () => {
  await db.query(`insert into public.reactions (souvenir_id, profil_id) values ($1, $2)`, [M.domicile, HOTE]);
  const reaction = (await notifs(AUTEUR)).find((n) => n.type === 'reaction');
  assert.equal(reaction.restaurant_genre, 'domicile');
});

console.log("\nL'hôte retire son nom, et rien d'autre");
await test('un inconnu ne peut pas retirer le nom (aucune ligne)', async () => {
  const r = await lu(ETRANGER, `update public.restaurants set hote_id = null where id = $1`, [CHEZ_EMMA]);
  reussit(r);
  assert.equal(r.nb, 0);
});
await test("l'auteur ne peut pas changer l'hôte (aucune ligne)", async () => {
  const r = await lu(AUTEUR, `update public.restaurants set hote_id = null where id = $1`, [CHEZ_EMMA]);
  reussit(r);
  assert.equal(r.nb, 0);
});
await test("l'hôte ne peut pas renommer le lieu", async () => {
  refuse(await lu(HOTE, `update public.restaurants set nom = 'Ailleurs' where id = $1`, [CHEZ_EMMA]), '42501');
});
await test("l'hôte ne peut pas mettre quelqu'un d'autre à sa place", async () => {
  refuse(await lu(HOTE, `update public.restaurants set hote_id = $2 where id = $1`, [CHEZ_EMMA, NOMME]), '42501');
});
await test("l'hôte retire son nom : permis", async () => {
  const r = await lu(HOTE, `update public.restaurants set hote_id = null where id = $1 returning hote_id`, [CHEZ_EMMA]);
  reussit(r);
  assert.deepEqual(r.rows, [{ hote_id: null }]);
});
await test('après coup, plus de notification « chez vous »', async () => {
  const chez = (await notifs(HOTE)).filter((n) => n.type === 'chez_vous');
  assert.equal(chez.length, 0);
});

console.log('\nLes « chez moi » déjà publiés (20261114010000)');
const FUITE = id(300); // « chez moi » saisi à la main, placé au domicile
const VRAI = id(301); // « Chez Léon » : un vrai restaurant saisi à la main
const PARTAGE = id(302); // « maison », mais un autre y a publié
await db.query(
  `insert into public.restaurants (id, nom, ville, quartier, cree_par, latitude, longitude)
   values ($1, 'chez moi', 'Liège', 'Outremeuse', $4, 50.64, 5.58),
          ($2, 'Chez Léon', 'Liège', null, $4, 50.63, 5.57),
          ($3, 'Maison', 'Liège', null, $4, 50.62, 5.56)`,
  [FUITE, VRAI, PARTAGE, AUTEUR],
);
await db.query(
  `insert into public.souvenirs (auteur_id, restaurant_id) values ($1, $2), ($3, $4)`,
  [AUTEUR, FUITE, HOTE, PARTAGE],
);
const correction = readFileSync(
  join(dossierMigrations, '20261114010000_chez_moi_sans_position.sql'),
  'utf8',
);
await db.exec(correction);
const ligne = async (rid) =>
  (await db.query(
    `select nom, ville, quartier, latitude, longitude, prive, genre from public.restaurants where id = $1`,
    [rid],
  )).rows[0];
await test('« chez moi » devient « Chez moi », sans position ni ville', async () => {
  assert.deepEqual(await ligne(FUITE), {
    nom: 'Chez moi', ville: '', quartier: null, latitude: null, longitude: null,
    prive: true, genre: 'domicile',
  });
});
await test('« Chez Léon » (vrai restaurant possible) reste tel quel', async () => {
  const r = await ligne(VRAI);
  assert.equal(r.prive, false);
  assert.equal(r.latitude, 50.63);
});
await test('« Maison » où un autre a publié reste tel quel (à vérifier à la main)', async () => {
  assert.equal((await ligne(PARTAGE)).prive, false);
});
await test('rejouée, la correction ne change plus rien', async () => {
  await db.exec(correction);
  assert.equal((await ligne(FUITE)).genre, 'domicile');
});
await test("l'auteur lit toujours son moment « Chez moi »", async () => {
  const r = await lu(AUTEUR, `select id from public.restaurants where id = $1`, [FUITE]);
  reussit(r);
  assert.equal(r.rows.length, 1);
});
await test('les autres ne le trouvent plus en dehors de ses moments', async () => {
  const r = await lu(ETRANGER, `select id from public.restaurants where id = $1`, [FUITE]);
  reussit(r);
  assert.equal(r.rows.length, 0);
});

console.log('\nLes anciens lieux personnels « chez moi » (20261114020000)');
const ANCIEN = id(310); // privé, sans genre, « chez moi »
const MAMIE = id(311); // privé, sans genre, « Chez Mamie »
await db.query(
  `insert into public.restaurants (id, nom, ville, cree_par, prive)
   values ($1, 'chez moi', '', $3, true), ($2, 'Chez Mamie', '', $3, true)`,
  [ANCIEN, MAMIE, AUTEUR],
);
await db.exec(
  readFileSync(join(dossierMigrations, '20261114020000_anciens_chez_moi_personnels.sql'), 'utf8'),
);
await test('« chez moi » privé devient « Chez moi », genre domicile', async () => {
  const r = await ligne(ANCIEN);
  assert.equal(r.nom, 'Chez moi');
  assert.equal(r.genre, 'domicile');
});
await test('« Chez Mamie » reste « chez quelqu’un » (sans genre)', async () => {
  assert.equal((await ligne(MAMIE)).genre, null);
});

console.log(`\n${nbTests} tests réussis.`);
