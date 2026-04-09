import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const GUARD_MARKER = 'SIGNET_FIRST_PROTOCOL';

const extractAndStripFrontmatter = (content) => {
  const match = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!match) return { frontmatter: {}, content };
  return { frontmatter: {}, content: match[2] };
};

export const SignetFirstBootstrapPlugin = async ({ client, directory }) => {
  const repoRoot = path.resolve(__dirname, '../..');
  const skillPath = path.join(repoRoot, 'SKILL.md');
  const parentDir = path.dirname(repoRoot);

  const getBootstrapContent = () => {
    if (!fs.existsSync(skillPath)) return null;

    const raw = fs.readFileSync(skillPath, 'utf8');
    const { content } = extractAndStripFrontmatter(raw);

    return `<${GUARD_MARKER}>
**IMPORTANT: The signet-first skill content is included below. It is ALREADY LOADED — you are currently following it. Do NOT use the skill tool to load "signet-first" again — that would be redundant.**

**MANDATORY — ON EVERY TURN: Search Signet memory BEFORE firing explore/librarian agents, reading files, or taking any action. Memory search takes <2s and may already contain what you need. External agents take minutes and cost tokens.**

${content}
</${GUARD_MARKER}>`;
  };

  return {
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(parentDir)) {
        config.skills.paths.push(parentDir);
      }
    },

    'experimental.chat.messages.transform': async (_input, output) => {
      const bootstrap = getBootstrapContent();
      if (!bootstrap || !output.messages.length) return;

      const firstUser = output.messages.find(m => m.info.role === 'user');
      if (!firstUser || !firstUser.parts.length) return;

      if (firstUser.parts.some(p => p.type === 'text' && p.text.includes(GUARD_MARKER))) return;

      const ref = firstUser.parts[0];
      firstUser.parts.unshift({ ...ref, type: 'text', text: bootstrap });
    }
  };
};
