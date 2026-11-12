// Conventional Commits. Merge commits created by GitHub are ignored by default.
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'subject-case': [2, 'never', ['upper-case', 'pascal-case', 'start-case']],
    'header-max-length': [2, 'always', 72],
    'type-enum': [2, 'always', ['feat', 'fix', 'docs', 'chore', 'ci', 'refactor', 'test', 'revert']],
  },
};
