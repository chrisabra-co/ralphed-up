const fs = require('fs');
const path = require('path');
const prompts = require('prompts');
const pc = require('picocolors');

const {
  IMPLEMENTATION_PLAN_TEMPLATE,
  AGENTS_MD_TEMPLATE,
  TASK_TEMPLATE,
  CONTEXT_GATHERING_AGENT,
  CODE_REVIEW_AGENT,
  LOGGING_AGENT,
} = require('./templates.js');

// Get the ralph-sessions.sh script content
const RALPH_SESSIONS_SCRIPT_URL = 'https://raw.githubusercontent.com/your-repo/ralph-sessions/main/ralph-sessions.sh';

async function detectTestCommand(projectDir) {
  // Check for common test configurations
  if (fs.existsSync(path.join(projectDir, 'package.json'))) {
    try {
      const pkg = JSON.parse(fs.readFileSync(path.join(projectDir, 'package.json'), 'utf-8'));
      if (pkg.scripts && pkg.scripts.test) {
        return 'npm test';
      }
    } catch (e) {
      // Ignore parse errors
    }
  }

  if (fs.existsSync(path.join(projectDir, 'pytest.ini')) ||
      fs.existsSync(path.join(projectDir, 'pyproject.toml'))) {
    return 'pytest';
  }

  if (fs.existsSync(path.join(projectDir, 'Cargo.toml'))) {
    return 'cargo test';
  }

  if (fs.existsSync(path.join(projectDir, 'go.mod'))) {
    return 'go test ./...';
  }

  if (fs.existsSync(path.join(projectDir, 'Makefile'))) {
    const makefile = fs.readFileSync(path.join(projectDir, 'Makefile'), 'utf-8');
    if (makefile.includes('test:')) {
      return 'make test';
    }
  }

  return '';
}

function createDirectories(baseDir) {
  const dirs = [
    '.claude/agents',
    'state',
    'logs/sessions',
    'logs/transcripts/logging',
    'plans',
    'templates',
  ];

  for (const dir of dirs) {
    const fullPath = path.join(baseDir, dir);
    if (!fs.existsSync(fullPath)) {
      fs.mkdirSync(fullPath, { recursive: true });
    }
  }
}

function copyRalphSessionsScript(baseDir) {
  // For now, create a placeholder that points to where the script should be
  // In a real npm package, this would be bundled
  const scriptPath = path.join(baseDir, 'ralph-sessions.sh');

  if (!fs.existsSync(scriptPath)) {
    // Create a minimal script that tells users to download the full version
    const minimalScript = `#!/usr/bin/env bash
#
# Ralph-Sessions: Hybrid Autonomous Development System
#
# This is a placeholder. Please download the full script from:
# ${RALPH_SESSIONS_SCRIPT_URL}
#
# Or copy it from the ralph-sessions repository.
#

echo "Please download the full ralph-sessions.sh script"
echo "See: ${RALPH_SESSIONS_SCRIPT_URL}"
exit 1
`;
    fs.writeFileSync(scriptPath, minimalScript);
    fs.chmodSync(scriptPath, '755');
    return false;
  }
  return true;
}

async function runSetup() {
  console.log('');
  console.log(pc.cyan('╔══════════════════════════════════════════════════════════════╗'));
  console.log(pc.cyan('║           Ralph-Sessions Setup Wizard                        ║'));
  console.log(pc.cyan('╚══════════════════════════════════════════════════════════════╝'));
  console.log('');

  // Get project directory
  const response = await prompts([
    {
      type: 'text',
      name: 'projectDir',
      message: 'Project directory:',
      initial: process.cwd(),
    },
    {
      type: 'confirm',
      name: 'hasImplementationPlan',
      message: 'Do you have an existing IMPLEMENTATION_PLAN.md?',
      initial: false,
    },
  ]);

  if (!response.projectDir) {
    console.log(pc.red('Setup cancelled.'));
    return;
  }

  const projectDir = path.resolve(response.projectDir);

  // Check if directory exists
  if (!fs.existsSync(projectDir)) {
    console.log(pc.red(`Directory does not exist: ${projectDir}`));
    return;
  }

  // Detect test command
  const detectedTestCommand = await detectTestCommand(projectDir);

  const testResponse = await prompts({
    type: 'text',
    name: 'testCommand',
    message: `Test command${detectedTestCommand ? ` (auto-detected: ${detectedTestCommand})` : ''}:`,
    initial: detectedTestCommand || 'npm test',
  });

  const testCommand = testResponse.testCommand || detectedTestCommand;

  console.log('');
  console.log(pc.cyan('Creating ralph-sessions structure...'));
  console.log('');

  // Create directories
  createDirectories(projectDir);
  console.log(pc.green('✓') + ' Created directories');

  // Create IMPLEMENTATION_PLAN.md if needed
  const implPlanPath = path.join(projectDir, 'IMPLEMENTATION_PLAN.md');
  if (!response.hasImplementationPlan && !fs.existsSync(implPlanPath)) {
    fs.writeFileSync(implPlanPath, IMPLEMENTATION_PLAN_TEMPLATE);
    console.log(pc.green('✓') + ' Created IMPLEMENTATION_PLAN.md');
  } else {
    console.log(pc.yellow('○') + ' IMPLEMENTATION_PLAN.md already exists');
  }

  // Create AGENTS.md
  const agentsPath = path.join(projectDir, 'AGENTS.md');
  if (!fs.existsSync(agentsPath)) {
    fs.writeFileSync(agentsPath, AGENTS_MD_TEMPLATE(testCommand));
    console.log(pc.green('✓') + ' Created AGENTS.md');
  } else {
    console.log(pc.yellow('○') + ' AGENTS.md already exists');
  }

  // Create agent files
  const agentsDir = path.join(projectDir, '.claude', 'agents');

  const contextGatheringPath = path.join(agentsDir, 'context-gathering.md');
  if (!fs.existsSync(contextGatheringPath)) {
    fs.writeFileSync(contextGatheringPath, CONTEXT_GATHERING_AGENT);
    console.log(pc.green('✓') + ' Created .claude/agents/context-gathering.md');
  }

  const codeReviewPath = path.join(agentsDir, 'code-review.md');
  if (!fs.existsSync(codeReviewPath)) {
    fs.writeFileSync(codeReviewPath, CODE_REVIEW_AGENT);
    console.log(pc.green('✓') + ' Created .claude/agents/code-review.md');
  }

  const loggingPath = path.join(agentsDir, 'logging.md');
  if (!fs.existsSync(loggingPath)) {
    fs.writeFileSync(loggingPath, LOGGING_AGENT);
    console.log(pc.green('✓') + ' Created .claude/agents/logging.md');
  }

  // Create template files
  const templatesDir = path.join(projectDir, 'templates');

  const taskTemplatePath = path.join(templatesDir, 'task.md');
  if (!fs.existsSync(taskTemplatePath)) {
    fs.writeFileSync(taskTemplatePath, TASK_TEMPLATE);
    console.log(pc.green('✓') + ' Created templates/task.md');
  }

  const implPlanTemplatePath = path.join(templatesDir, 'IMPLEMENTATION_PLAN.md');
  if (!fs.existsSync(implPlanTemplatePath)) {
    fs.writeFileSync(implPlanTemplatePath, IMPLEMENTATION_PLAN_TEMPLATE);
    console.log(pc.green('✓') + ' Created templates/IMPLEMENTATION_PLAN.md');
  }

  const agentsTemplatePath = path.join(templatesDir, 'AGENTS.md');
  if (!fs.existsSync(agentsTemplatePath)) {
    fs.writeFileSync(agentsTemplatePath, AGENTS_MD_TEMPLATE(testCommand));
    console.log(pc.green('✓') + ' Created templates/AGENTS.md');
  }

  // Create state files
  const stateDir = path.join(projectDir, 'state');

  const iterationPath = path.join(stateDir, 'iteration.json');
  if (!fs.existsSync(iterationPath)) {
    fs.writeFileSync(iterationPath, JSON.stringify({ iteration: 0, task_index: 0 }, null, 2));
    console.log(pc.green('✓') + ' Created state/iteration.json');
  }

  const backlogPath = path.join(stateDir, 'backlog-queue.json');
  if (!fs.existsSync(backlogPath)) {
    fs.writeFileSync(backlogPath, '[]');
    console.log(pc.green('✓') + ' Created state/backlog-queue.json');
  }

  // Note about ralph-sessions.sh
  const scriptExists = copyRalphSessionsScript(projectDir);

  console.log('');
  console.log(pc.green('Ralph-Sessions initialized successfully!'));
  console.log('');
  console.log('Next steps:');
  console.log('  1. Edit IMPLEMENTATION_PLAN.md to add your tasks');
  console.log('  2. Edit AGENTS.md to configure project conventions');
  if (!scriptExists) {
    console.log(pc.yellow('  3. Download the full ralph-sessions.sh script'));
  }
  console.log('  ' + (scriptExists ? '3' : '4') + '. Run: ./ralph-sessions.sh single');
  console.log('');
}

module.exports = { runSetup };
