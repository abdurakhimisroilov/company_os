const { newDb } = require('pg-mem');
const path = require('path');
const crypto = require('crypto');

async function test() {
  const db = newDb({ autoCreateForeignKeyIndices: true });
  db.public.registerFunction({
    name: 'current_database',
    implementation: () => 'company_os',
  });
  db.public.registerFunction({
    name: 'version',
    implementation: () => 'PostgreSQL 15.0 on x86_64',
  });
  db.public.registerFunction({
    name: 'uuid_generate_v4',
    implementation: () => crypto.randomUUID(),
  });

  const ds = await db.adapters.createTypeormDataSource({
    type: 'postgres',
    entities: [path.join(__dirname, 'dist/**/*.entity.js')],
    synchronize: true,
  });

  await ds.initialize();
  console.log('SUCCESS! Initialized with all entities! Entity count:', ds.entityMetadatas.length);
  await ds.destroy();
}

test().catch(err => {
  console.error('Error:', err);
});
