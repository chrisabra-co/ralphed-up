#!/usr/bin/env node

const { runSetup } = require('../lib/setup.js');

async function main() {
  try {
    await runSetup();
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

main();
