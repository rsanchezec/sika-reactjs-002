#!/usr/bin/env node
/**
 * Script para verificar qué variables de entorno cargará Vite
 * Uso: node check-env.js [development|production]
 */

import { loadEnv } from 'vite';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const mode = process.argv[2] || 'development';

console.log(`\n🔍 Verificando variables para modo: ${mode}\n`);

const env = loadEnv(mode, __dirname, 'VITE_');

console.log('📋 Variables VITE_* encontradas:');
console.log('─'.repeat(60));

if (Object.keys(env).length === 0) {
  console.log('❌ No se encontraron variables VITE_*');
  console.log(`   Asegúrate de que existe: .env.${mode}`);
} else {
  for (const [key, value] of Object.entries(env)) {
    console.log(`✅ ${key}=${value}`);
  }
}

console.log('─'.repeat(60));
console.log(`\n📄 Archivo cargado: .env.${mode}\n`);
