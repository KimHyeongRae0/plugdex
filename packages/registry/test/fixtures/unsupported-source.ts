/**
 * AC-2, negative half: the git/url install-source form must NOT compile.
 *
 * The CLI's marketplace context does not support this form. Declaring it unrepresentable
 * in the type is only worth something if a fixture demonstrates the compiler refusing it,
 * so this file is expected to fail `tsc` and the scenario asserts that it does.
 */
import type { InstallSource } from '../../src/schema';

// No suppression directive appears in this file, and the sentence above is written to
// avoid starting a comment line with one: a line beginning `// @ts-` + `expect-error` is
// itself the directive, and an earlier draft of this comment silently suppressed the very
// error the scenario asserts, leaving tsc exiting 0 on a fixture that must fail.
export const unsupported: InstallSource = { source: 'git', url: 'https://example.com/x.git' };
