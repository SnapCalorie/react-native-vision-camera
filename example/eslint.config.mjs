import { fixupConfigRules, fixupPluginRules } from '@eslint/compat';
import react from 'eslint-plugin-react';
import reactHooks from 'eslint-plugin-react-hooks';
import _import from 'eslint-plugin-import';
import typescriptEslint from '@typescript-eslint/eslint-plugin';
import prettier from 'eslint-plugin-prettier';
import globals from 'globals';
import tsParser from '@typescript-eslint/parser';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import js from '@eslint/js';
import { FlatCompat } from '@eslint/eslintrc';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const compat = new FlatCompat({
  baseDirectory: __dirname,
  recommendedConfig: js.configs.recommended,
  allConfig: js.configs.all,
});

export default [
  {
    ignores: [
      '.expo',
      '**/temp.js',
      'config/*',
      '**/RawData.ts',
      '**/node_modules/',
      '**/assets/',
      '**/android/',
      '**/ios/',
      'components/swipeout/',
      'components/swipeableviews/',
      '**/dist/',
      '**/jest.config.js',
    ],
  },
  ...fixupConfigRules(
    compat.extends(
      'plugin:react/recommended',
      'plugin:import/recommended',
      'airbnb',
      'airbnb/hooks',
      'plugin:prettier/recommended',
      'plugin:react/jsx-runtime',
      'plugin:@tanstack/eslint-plugin-query/recommended'
    )
  ),
  {
    plugins: {
      react: fixupPluginRules(react),
      'react-hooks': fixupPluginRules(reactHooks),
      import: fixupPluginRules(_import),
      '@typescript-eslint': typescriptEslint,
      prettier: fixupPluginRules(prettier),
      // "@tanstack/query": fixupPluginRules(tanstackQuery),
    },

    languageOptions: {
      globals: {
        ...globals.browser,
        ...globals.node,
        ...globals.jest,
      },

      parser: tsParser,
      ecmaVersion: 13,
      sourceType: 'module',

      parserOptions: {
        ecmaFeatures: {
          jsx: true,
        },
      },
    },

    settings: {
      'import/resolver': {
        node: {
          extensions: ['.js', '.jsx', '.ts', '.tsx'],
        },
      },
    },

    rules: {
      '@typescript-eslint/no-shadow': 'error',

      '@typescript-eslint/no-unused-vars': [
        'error',
        {
          varsIgnorePattern: 'set.+|_.+',
        },
      ],

      'func-names': 'off',
      'import/extensions': ['error', 'never'],

      'import/no-extraneous-dependencies': [
        'error',
        {
          devDependencies: true,
        },
      ],

      'import/no-mutable-exports': 'off',
      'import/prefer-default-export': 'off',

      'max-len': [
        'error',
        {
          code: 120,
        },
      ],

      'no-console': 'off',
      'no-nested-ternary': 'off',

      'no-param-reassign': [
        'off',
        {
          props: true,
          ignorePropertyModificationsFor: ['state'],
        },
      ],

      'no-shadow': 'off',
      'no-underscore-dangle': 'off',
      'no-unused-vars': 'off',

      'no-use-before-define': [
        'error',
        {
          functions: false,
          classes: true,
          variables: false,
        },
      ],

      'no-useless-constructor': 'off',
      'no-var': 'off',
      'object-shorthand': 'off',
      'operator-assignment': 'off',
      'prefer-destructuring': 'off',

      'prettier/prettier': [
        'error',
        {
          singleQuote: true,
          printWidth: 120,
          trailingComma: 'es5',
        },
        {
          usePrettierrc: false,
        },
      ],

      'react/destructuring-assignment': 'off',
      'react/require-default-props': 'off',

      'react/jsx-filename-extension': [
        2,
        {
          extensions: ['.jsx', '.tsx'],
        },
      ],

      'react/jsx-no-bind': [
        'warn',
        {
          ignoreDOMComponents: true,
          ignoreRefs: false,
          allowArrowFunctions: true,
          allowFunctions: true,
          allowBind: true,
        },
      ],

      'react/forbid-prop-types': 'off',
      'react/function-component-definition': 'off',
      'react-hooks/rules-of-hooks': 'error',
      'react-hooks/exhaustive-deps': ['warn', { additionalHooks: '(useFrameProcessor|useSkiaFrameProcessor)' }],
      'vars-on-top': 'off',
      'no-restricted-syntax': 0,
    },
  },
  {
    files: ['**/*.ts', '**/*.tsx'],

    rules: {
      'no-undef': 'off',
    },
  },
];
