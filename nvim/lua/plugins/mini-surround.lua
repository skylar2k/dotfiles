-- Add, delete and replace surrounding pairs:
--   sa{motion}{char}  add     saiw"  -> "word"
--   sd{char}          delete  sd"    -> word
--   sr{old}{new}      replace sr"'   -> 'word'
-- Also sf/sF (find), sh (highlight). This takes over `s`; use `cl` for the old substitute-char.
return {
    profile = "lite",
    src = {
        "https://github.com/nvim-mini/mini.surround",
    },
    setup = function()
        require("mini.surround").setup()
    end,
}
