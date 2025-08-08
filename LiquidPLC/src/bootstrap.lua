-- File: src/bootstrap.lua
-- You need to require this at the start of any entry point
-- Or you won't be able to load modules from /vendor

-- Get the path of this bootstrap file itself.
local bootstrap_path = "src/bootstrap.lua"

-- Extract the directory part of the path.
-- The pattern matches from the start ('@' is optional) up to the last '/' or '\'.
local src_dir = bootstrap_path:match("@?(.*[/\\])")

-- The project root is one directory above the 'src' directory.
local project_root = src_dir .. "../"

-- Prepend our new paths to the existing package.path.
-- Prepending ensures our project's modules are found before any conflicting system modules.
-- Add vendor and src directories to package.path
package.path = project_root .. "../vendor/?.lua;" ..
               project_root .. "../src/?.lua;" ..
               package.path