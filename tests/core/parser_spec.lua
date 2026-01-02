-- Tests for core/parser.lua

local parser = require('remora.core.parser')

describe('parser', function()
  describe('parse_ai_review', function()
    it('should parse formatted AI review response', function()
      local response = [[
SUMMARY: This PR adds a new authentication feature with JWT support.

FINDING: auth/jwt.lua:42
SEVERITY: high
TITLE: Missing token expiration check
DESCRIPTION: The JWT verification does not check token expiration, which could allow expired tokens to be used.
---
FINDING: auth/middleware.lua:15
SEVERITY: medium
TITLE: Error handling could be improved
DESCRIPTION: The middleware does not properly handle authentication errors, which could leak sensitive information.
---
]]

      local review = parser.parse_ai_review(response)

      -- Check summary
      assert.is_not_nil(review.summary)
      assert.truthy(review.summary:match('JWT support'))

      -- Check findings
      assert.equals(2, #review.findings)

      -- Check first finding
      local finding1 = review.findings[1]
      assert.equals('auth/jwt.lua', finding1.file)
      assert.equals(42, finding1.line)
      assert.equals('high', finding1.severity)
      assert.truthy(finding1.title:match('token expiration'))

      -- Check second finding
      local finding2 = review.findings[2]
      assert.equals('auth/middleware.lua', finding2.file)
      assert.equals(15, finding2.line)
      assert.equals('medium', finding2.severity)
    end)

    it('should handle response without formatted findings', function()
      local response = [[
This code looks good overall. The implementation is clean and follows best practices.
However, there are a few minor suggestions I'd make.
]]

      local review = parser.parse_ai_review(response)

      assert.is_not_nil(review.summary)
      assert.equals(0, #review.findings)
    end)

    it('should handle empty response', function()
      local review = parser.parse_ai_review('')

      assert.is_not_nil(review.summary)
      assert.equals(0, #review.findings)
    end)
  end)

  describe('_parse_finding_block', function()
    it('should parse finding with all fields', function()
      local block = [[
FINDING: src/utils/helpers.lua:25
SEVERITY: critical
TITLE: SQL Injection vulnerability
DESCRIPTION: User input is directly interpolated into SQL query without sanitization.
]]

      local finding = parser._parse_finding_block(block)

      assert.is_not_nil(finding)
      assert.equals('src/utils/helpers.lua', finding.file)
      assert.equals(25, finding.line)
      assert.equals('critical', finding.severity)
      assert.truthy(finding.title:match('SQL Injection'))
    end)

    it('should handle alternate format', function()
      local block = [[
File: config/database.lua
Line: 100
SEVERITY: low
TITLE: Hardcoded credentials
DESCRIPTION: Database password is hardcoded in the configuration file.
]]

      local finding = parser._parse_finding_block(block)

      assert.is_not_nil(finding)
      assert.equals('config/database.lua', finding.file)
      assert.equals(100, finding.line)
      assert.equals('low', finding.severity)
    end)

    it('should return nil for block without file/line', function()
      local block = [[
This is just a general comment without specific file reference.
]]

      local finding = parser._parse_finding_block(block)
      assert.is_nil(finding)
    end)
  end)

  describe('parse_diff_positions', function()
    it('should calculate diff positions correctly', function()
      local diff = [[
diff --git a/test.lua b/test.lua
index 1234567..abcdefg 100644
--- a/test.lua
+++ b/test.lua
@@ -1,5 +1,6 @@
 local M = {}

+-- New comment
 function M.test()
   return true
 end
]]

      local positions = parser.parse_diff_positions(diff)

      assert.is_table(positions)
      assert.is_not_nil(positions[3]) -- Line 3 is the new comment
    end)

    it('should handle empty diff', function()
      local positions = parser.parse_diff_positions('')
      assert.is_table(positions)
      assert.equals(0, vim.tbl_count(positions))
    end)
  end)

  describe('extract_suggestion', function()
    it('should extract suggestion from comment body', function()
      local body = [[
This could be improved:

```suggestion
function better_implementation()
  return optimized_result
end
```
]]

      local suggestion = parser.extract_suggestion(body)

      assert.is_not_nil(suggestion)
      assert.truthy(suggestion:match('better_implementation'))
    end)

    it('should return nil when no suggestion', function()
      local body = 'This is just a comment without suggestion'
      local suggestion = parser.extract_suggestion(body)
      assert.is_nil(suggestion)
    end)
  end)

  describe('build_suggestion_markdown', function()
    it('should build suggestion markdown', function()
      local code = 'local x = improved_value'
      local markdown = parser.build_suggestion_markdown(code)

      assert.truthy(markdown:match('```suggestion'))
      assert.truthy(markdown:match('improved_value'))
    end)
  end)

  describe('parse_github_diff', function()
    it('should parse diff and extract file changes', function()
      local diff = [[
diff --git a/file1.lua b/file1.lua
index 1234567..abcdefg 100644
--- a/file1.lua
+++ b/file1.lua
@@ -1,3 +1,4 @@
+local new_line = true
 local M = {}

 function M.test()
diff --git a/file2.lua b/file2.lua
index abcdefg..1234567 100644
--- a/file2.lua
+++ b/file2.lua
@@ -1,2 +1,1 @@
-local removed_line = true
 local M = {}
]]

      local files = parser.parse_github_diff(diff)

      assert.equals(2, #files)

      -- Check file1
      assert.equals('file1.lua', files[1].path)
      assert.equals(1, files[1].additions)
      assert.equals(0, files[1].deletions)

      -- Check file2
      assert.equals('file2.lua', files[2].path)
      assert.equals(0, files[2].additions)
      assert.equals(1, files[2].deletions)
    end)
  end)

  describe('parse_pr_description', function()
    it('should extract issue references', function()
      local description = 'This PR fixes #123 and addresses #456'
      local info = parser.parse_pr_description(description)

      assert.equals(2, #info.related_issues)
      assert.is_true(vim.tbl_contains(info.related_issues, 123))
      assert.is_true(vim.tbl_contains(info.related_issues, 456))
    end)

    it('should extract breaking changes', function()
      local description = [[
## Breaking Changes
- Removed deprecated API
- Changed function signature
]]

      local info = parser.parse_pr_description(description)

      assert.is_true(#info.breaking_changes > 0)
    end)

    it('should extract testing notes', function()
      local description = [[
## Testing
- Run unit tests
- Test with production data
]]

      local info = parser.parse_pr_description(description)

      assert.is_not_nil(info.testing_notes)
      assert.truthy(info.testing_notes:match('unit tests'))
    end)

    it('should handle nil description', function()
      local info = parser.parse_pr_description(nil)

      assert.is_table(info)
      assert.equals(0, #info.related_issues)
      assert.equals(0, #info.breaking_changes)
    end)
  end)
end)
