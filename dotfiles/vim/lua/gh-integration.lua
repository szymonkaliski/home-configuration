local M = {}

local is_macos = vim.fn.has('macunix') == 1

-- repository URL
local function repo_url()
  local url = vim.fn.trim(vim.fn.system('gh repo view --json url --jq .url'))
  if url ~= '' then return url end

  -- fallback: extract and convert "git@github.com:owner/repo.git"
  local remote = vim.fn.trim(vim.fn.system('git config --get remote.origin.url'))
  return remote:gsub('^git@github.com:', 'https://github.com/'):gsub('%.git$', '')
end

-- path relative to the git root
local function relative_path()
  local root = vim.fn.trim(vim.fn.system('git rev-parse --show-toplevel'))
  if root == '' then return nil end
  local abs  = vim.fn.expand('%:p'):gsub('\\','/')
  root       = root:gsub('\\','/')
  return abs:gsub('^'..root..'/', '')
end

-- final blob URL pinned to the current commit and line(s)
local function make_url(first, last)
  local repo = repo_url();
  if repo == '' then return nil end

  local path = relative_path();
  if not path then return nil end

  local sha  = vim.fn.trim(vim.fn.system('git rev-parse HEAD'))
  local frag = (first == last) and ('L'..first) or ('L'..first..'-L'..last)

  return ("%s/blob/%s/%s#%s"):format(repo, sha, path, frag)
end

local function browse(first, last)
  local url = make_url(first, last)
  if not url then
    vim.notify('GHBrowse: unable to build URL', vim.log.levels.ERROR)
    return
  end

  if is_macos then
    vim.fn.jobstart({ 'open', url }, { detach = true })
  else
    vim.notify(url, vim.log.levels.INFO)
  end
end

function M.init()
  vim.api.nvim_create_user_command('GHBrowse', function(o)
    browse(o.line1, o.line2)
  end, { range = '%' })
end

return M
