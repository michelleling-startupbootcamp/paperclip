import postgres from 'postgres';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);

const sql = postgres('postgresql://neondb_owner:npg_tZAjVy7OpN2u@ep-damp-lake-amws2x10-pooler.c-5.us-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require');

// Check if paperclip database exists
const rows = await sql`SELECT datname FROM pg_database WHERE datname = 'paperclip'`;
console.log('Existing databases:', JSON.stringify(rows));

if (rows.length === 0) {
  console.log('Creating paperclip database...');
  await sql`CREATE DATABASE paperclip`;
  console.log('Created paperclip database');
} else {
  console.log('paperclip database already exists');
}

await sql.end();
