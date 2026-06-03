#!/usr/bin/env node
// OpSkill — SessionStart activation hook
// Reads all skill.md files from plugin cache and injects them as session context.
// Skills become available as slash commands Claude recognizes and acts on.

const fs = require('fs');
const path = require('path');
const os = require('os');

// Plugin system sets CLAUDE_PLUGIN_ROOT. Fall back to legacy cache path for
// standalone (settings.json-registered) installs.
const claudeDir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude');
const pluginBase = process.env.CLAUDE_PLUGIN_ROOT
  || path.join(claudeDir, 'plugins', 'cache', 'opskill', 'opskill', 'local');
const pluginPath = path.join(pluginBase, 'skills');
const configPath = path.join(pluginBase, 'models.json');

const SKILLS = ['mix', 'aceopti', 'aceopti-setup', 'acesidekick'];

function readSkill(name) {
  try {
    const content = fs.readFileSync(path.join(pluginPath, name, 'skill.md'), 'utf8');
    // Strip YAML frontmatter
    return content.replace(/^---[\s\S]*?---\n/, '').trim();
  } catch (e) {
    return null;
  }
}

// Load model config if exists
let modelConfig = {
  coding_heavy: 'qwen2.5-coder:14b',
  coding_fast: 'qwen2.5-coder:7b',
  embeddings: 'nomic-embed-text'
};
try {
  modelConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));
} catch (e) { /* use defaults */ }

const modelNote = `## acesidekick model config

| Role | Model |
|---|---|
| Coding (heavy) | \`${modelConfig.coding_heavy}\` |
| Coding (fast) | \`${modelConfig.coding_fast}\` |
| Embeddings | \`${modelConfig.embeddings}\` |

Use these exact model names in all Ollama API calls. Do not substitute other models unless user explicitly requests.
`;

const parts = [];

for (const skill of SKILLS) {
  const content = readSkill(skill);
  if (content) {
    // Inject model config into acesidekick skill
    if (skill === 'acesidekick') {
      parts.push(`## /${skill}\n\n${modelNote}\n\n${content}`);
    } else {
      parts.push(`## /${skill}\n\n${content}`);
    }
  }
}

if (parts.length === 0) {
  process.stdout.write('');
  process.exit(0);
}

const output = `# OpSkill Active

Skills loaded: ${SKILLS.map(s => '/' + s).join('  ')}
Models: coding=${modelConfig.coding_heavy} | fast=${modelConfig.coding_fast} | embed=${modelConfig.embeddings}

${parts.join('\n\n---\n\n')}
`;

process.stdout.write(output);
process.exit(0);
