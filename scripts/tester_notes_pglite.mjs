// Test PGlite de `souvenirs.notes` (étoiles facultatives) : rejoue toutes les
// migrations avec de faux éléments Supabase, puis teste accès permis et refusés.
//
//   npm install --prefix /tmp/tabl-pglite @electric-sql/pglite
//   node scripts/tester_notes_pglite.mjs
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
const ABONNE = id(2); // abonnement accepté
const ETRANGER = id(3); // aucun lien
const NOMME = id(4); // nommé dans une audience « seulement »
const EXCLU = id(5); // exclu d'une audience « sauf », pourtant abonné
const RESTO = id(100);
const M = {
  tous: id(201),
  brouillon: id(202),
  seulement: id(203),
  sauf: id(204),
  public: id(205),
};
const NOTES = { cuisine: 4, ambiance: 3 };

for (const [n, pseudo] of [[1, 'auteur'], [2, 'abonne'], [3, 'etranger'], [4, 'nomme'], [5, 'exclu']]) {
  await db.query(`insert into auth.users (id, email) values ($1, $2)`, [id(n), `${pseudo}@test.fr`]);
  await db.query(`insert into public.profils (id, pseudo) values ($1, $2) on conflict do nothing`, [id(n), pseudo]);
}
await db.query(`insert into public.restaurants (id, nom, ville, cree_par) values ($1, 'Chez Test', 'Liège', $2)`, [RESTO, AUTEUR]);
for (const suiveur of [ABONNE, EXCLU]) {
  await db.query(
    `insert into public.abonnements (suiveur_id, suivi_id, statut) values ($1, $2, 'accepte')`,
    [suiveur, AUTEUR],
  );
}
async function souvenir(idm, { statut = 'publie', visibilite = 'tout_le_monde', notes = NOTES } = {}) {
  await db.query(
    `insert into public.souvenirs (id, auteur_id, restaurant_id, statut, visibilite, notes)
     values ($1, $2, $3, $4, $5, $6)`,
    [idm, AUTEUR, RESTO, statut, visibilite, notes === null ? null : JSON.stringify(notes)],
  );
}
await souvenir(M.tous);
await souvenir(M.brouillon, { statut: 'brouillon' });
await souvenir(M.seulement, { visibilite: 'seulement' });
await souvenir(M.sauf, { visibilite: 'sauf' });
await db.query(`insert into public.souvenirs_audience (souvenir_id, profil_id) values ($1, $2), ($3, $4)`, [
  M.seulement, NOMME, M.sauf, EXCLU,
]);

// ------------------------------------------------------------
//  Tests
// ------------------------------------------------------------
console.log('\nColonne');
await test('notes existe : jsonb, nullable, sans valeur par défaut', async () => {
  const { rows } = await db.query(
    `select data_type, is_nullable, column_default from information_schema.columns
     where table_schema = 'public' and table_name = 'souvenirs' and column_name = 'notes'`,
  );
  assert.deepEqual(rows, [{ data_type: 'jsonb', is_nullable: 'YES', column_default: null }]);
});

await test("les moments existants ne sont pas touchés (notes null par défaut)", async () => {
  await db.query(`insert into public.souvenirs (id, auteur_id, restaurant_id) values ($1, $2, $3)`, [id(299), AUTEUR, RESTO]);
  const { rows } = await db.query(`select notes from public.souvenirs where id = $1`, [id(299)]);
  assert.equal(rows[0].notes, null);
  await db.query(`delete from public.souvenirs where id = $1`, [id(299)]);
});

console.log("\nL'auteur écrit et relit ses notes");
await test("lit les notes insérées, telles quelles", async () => {
  const r = await lu(AUTEUR, `select notes from public.souvenirs where id = $1`, [M.tous]);
  reussit(r);
  assert.deepEqual(r.rows, [{ notes: NOTES }]);
});
await test('insère un moment avec notes (comme l’app)', async () => {
  const r = await lu(
    AUTEUR,
    `insert into public.souvenirs (id, auteur_id, restaurant_id, statut, notes)
     values ($1, $2, $3, 'brouillon', $4) returning notes`,
    [id(210), AUTEUR, RESTO, JSON.stringify({ cuisine: 5, lieu: 2 })],
  );
  reussit(r);
  assert.deepEqual(r.rows, [{ notes: { cuisine: 5, lieu: 2 } }]);
});
await test('modifie ses notes (update), puis les efface (null)', async () => {
  const maj = await lu(AUTEUR, `update public.souvenirs set notes = $2 where id = $1 returning notes`, [
    M.tous, JSON.stringify({ cuisine: 1, service: 5, qualite_prix: 0 }),
  ]);
  reussit(maj);
  assert.deepEqual(maj.rows[0].notes, { cuisine: 1, service: 5, qualite_prix: 0 });
  const raz = await lu(AUTEUR, `update public.souvenirs set notes = null where id = $1 returning notes`, [M.tous]);
  reussit(raz);
  assert.equal(raz.rows[0].notes, null);
  await db.query(`update public.souvenirs set notes = $2 where id = $1`, [M.tous, JSON.stringify(NOTES)]);
});
await test('relit les notes de son brouillon', async () => {
  const r = await lu(AUTEUR, `select notes from public.souvenirs where id = $1`, [M.brouillon]);
  reussit(r);
  assert.deepEqual(r.rows, [{ notes: NOTES }]);
});

console.log('\nForme des notes (contrainte)');
await test("un tableau est refusé (23514)", async () => {
  refuse(await lu(AUTEUR, `update public.souvenirs set notes = '[1,2]' where id = $1`, [M.tous]), '23514');
});
await test("un nombre ou une chaîne sont refusés (23514)", async () => {
  refuse(await lu(AUTEUR, `update public.souvenirs set notes = '4' where id = $1`, [M.tous]), '23514');
  refuse(await lu(AUTEUR, `update public.souvenirs set notes = '"cuisine"' where id = $1`, [M.tous]), '23514');
});
await test("le JSON « null » est refusé (seul le NULL SQL dit « pas de notes »)", async () => {
  refuse(await lu(AUTEUR, `update public.souvenirs set notes = 'null'::jsonb where id = $1`, [M.tous]), '23514');
});
await test("un objet vide est accepté", async () => {
  reussit(await lu(AUTEUR, `update public.souvenirs set notes = '{}' where id = $1`, [M.tous]));
  await db.query(`update public.souvenirs set notes = $2 where id = $1`, [M.tous, JSON.stringify(NOTES)]);
});

console.log('\nUn tiers ne lit les notes que s’il peut voir le moment');
const attendu = [
  // [qui, moment, visible ?, raison]
  [ABONNE, 'tous', true, 'abonné accepté, « Tout le monde »'],
  [ETRANGER, 'tous', false, 'sans abonnement, profil privé'],
  [ABONNE, 'brouillon', false, 'brouillon invisible, même pour un abonné'],
  [ETRANGER, 'brouillon', false, 'brouillon invisible'],
  [NOMME, 'seulement', true, '« Seulement » : personne nommée'],
  [ABONNE, 'seulement', false, '« Seulement » : abonné non nommé'],
  [ETRANGER, 'seulement', false, '« Seulement » : étranger'],
  [EXCLU, 'sauf', false, '« Sauf » : exclu, pourtant abonné'],
  [ABONNE, 'sauf', true, '« Sauf » : abonné non exclu'],
  [AUTEUR, 'brouillon', true, 'l’auteur, brouillon inclus'],
  [AUTEUR, 'sauf', true, 'l’auteur, toujours'],
];
for (const [qui, cle, visible, raison] of attendu) {
  await test(`${raison} → notes ${visible ? 'lues' : 'invisibles'}`, async () => {
    const r = await lu(qui, `select notes from public.souvenirs where id = $1`, [M[cle]]);
    reussit(r);
    if (visible) assert.deepEqual(r.rows, [{ notes: NOTES }]);
    else assert.deepEqual(r.rows, []);
    // La lecture suit exactement `peut_voir_souvenir()`.
    const p = await lu(qui, `select public.peut_voir_souvenir($1) as v`, [M[cle]]);
    assert.equal(p.rows[0].v, visible);
  });
}
await test('profil public : un étranger lit les notes d’un moment « Tout le monde »', async () => {
  await db.query(`update public.profils set est_prive = false where id = $1`, [AUTEUR]);
  await souvenir(M.public);
  const r = await lu(ETRANGER, `select notes from public.souvenirs where id = $1`, [M.public]);
  reussit(r);
  assert.deepEqual(r.rows, [{ notes: NOTES }]);
  await db.query(`delete from public.souvenirs where id = $1`, [M.public]);
  await db.query(`update public.profils set est_prive = true where id = $1`, [AUTEUR]);
});
await test('lecture en masse : un tiers ne voit que les notes des moments visibles', async () => {
  const r = await lu(ABONNE, `select id from public.souvenirs where notes is not null order by id`);
  reussit(r);
  assert.deepEqual(r.rows.map((x) => x.id), [M.tous, M.sauf]);
});
await test('on ne retrouve pas les notes par un filtre sur notes (pas de fuite par recherche)', async () => {
  const r = await lu(ETRANGER, `select count(*)::int as n from public.souvenirs where notes @> '{"cuisine":4}'`);
  reussit(r);
  assert.equal(r.rows[0].n, 0);
});

console.log('\nUn tiers n’écrit pas les notes d’autrui');
await test('update des notes d’un autre : 0 ligne touchée, notes intactes', async () => {
  const r = await lu(ABONNE, `update public.souvenirs set notes = '{"cuisine":0}' where id = $1 returning id`, [M.tous]);
  reussit(r);
  assert.equal(r.rows.length, 0);
  const { rows } = await db.query(`select notes from public.souvenirs where id = $1`, [M.tous]);
  assert.deepEqual(rows[0].notes, NOTES);
});
await test('insertion d’un moment au nom d’un autre refusée (42501)', async () => {
  refuse(
    await lu(ABONNE, `insert into public.souvenirs (auteur_id, restaurant_id, notes) values ($1, $2, '{"cuisine":5}')`, [AUTEUR, RESTO]),
    '42501',
  );
});
await test('un auteur ne peut pas confier son moment à un autre en changeant auteur_id (42501)', async () => {
  refuse(await lu(AUTEUR, `update public.souvenirs set auteur_id = $2 where id = $1`, [M.tous, ABONNE]), '42501');
});

console.log('\nAutres rôles');
await test('anon : aucun accès à souvenirs (42501)', async () => {
  refuse(await en('anon', null, `select notes from public.souvenirs`), '42501');
});
await test('service_role : ne lit pas notes (grants par colonne), lit toujours id et auteur_id', async () => {
  refuse(await en('service_role', null, `select notes from public.souvenirs`), '42501');
  refuse(await en('service_role', null, `select * from public.souvenirs`), '42501');
  reussit(await en('service_role', null, `select id, auteur_id from public.souvenirs`));
});

console.log('\nRègle 42P17 et droits');
await test('aucune policy de souvenirs ne relit souvenirs directement', async () => {
  const { rows } = await db.query(
    `select policyname, coalesce(qual, '') || ' ' || coalesce(with_check, '') as expr
     from pg_policies where schemaname = 'public' and tablename = 'souvenirs'`,
  );
  assert.ok(rows.length >= 4, 'policies de souvenirs introuvables');
  const fautives = rows.filter((p) => /\b(from|join)\s+(public\.)?souvenirs\b/i.test(p.expr));
  assert.deepEqual(fautives, []);
});
await test('les droits de table de souvenirs n’ont pas bougé (pas de grant par colonne sur notes)', async () => {
  const { rows } = await db.query(
    `select privilege_type from information_schema.role_table_grants
     where table_schema = 'public' and table_name = 'souvenirs' and grantee = 'authenticated'
     order by privilege_type`,
  );
  assert.deepEqual(rows.map((r) => r.privilege_type), ['DELETE', 'INSERT', 'SELECT', 'UPDATE']);
  const col = await db.query(
    `select 1 from information_schema.column_privileges
     where table_schema = 'public' and table_name = 'souvenirs' and column_name = 'notes'
       and grantee = 'authenticated' and privilege_type = 'UPDATE'`,
  );
  assert.equal(col.rows.length, 1);
});

console.log('\nPetit-déjeuner et notes écrites');
await test("moment : 'matin', 'midi' et 'soir' acceptés, autre chose refusé", async () => {
  for (const [n, moment] of [[311, 'matin'], [312, 'midi'], [313, 'soir']]) {
    reussit(await lu(AUTEUR, `insert into public.souvenirs (id, auteur_id, restaurant_id, moment) values ($1, $2, $3, $4)`, [id(n), AUTEUR, RESTO, moment]));
  }
  refuse(await lu(AUTEUR, `insert into public.souvenirs (id, auteur_id, restaurant_id, moment) values ($1, $2, $3, 'gouter')`, [id(314), AUTEUR, RESTO]), '23514');
  reussit(await lu(AUTEUR, `update public.souvenirs set moment = 'matin' where id = $1`, [id(312)]));
  await db.query(`delete from public.souvenirs where id in ($1, $2, $3)`, [id(311), id(312), id(313)]);
});
await test('notes : les plats écrits (une liste sous "plats") sont acceptés et relus', async () => {
  const notes = { cuisine: 4, plats: [{ nom: 'Risotto', note: 5 }, { nom: 'Tiramisu', note: 3 }] };
  reussit(await lu(AUTEUR, `insert into public.souvenirs (id, auteur_id, restaurant_id, notes) values ($1, $2, $3, $4)`, [id(315), AUTEUR, RESTO, JSON.stringify(notes)]));
  const r = await lu(ABONNE, `select notes from public.souvenirs where id = $1`, [id(315)]);
  reussit(r);
  assert.deepEqual(r.rows[0].notes, notes);
  await db.query(`delete from public.souvenirs where id = $1`, [id(315)]);
});

console.log(`\n${nbTests} tests passés${process.exitCode ? ' — AVEC ÉCHECS' : ''}.`);
await db.close();
