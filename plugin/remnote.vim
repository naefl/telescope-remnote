function! SendToRemnote()
    lua for k in pairs(package.loaded) do if k:match("^remnote") then package.loaded[k] = nil end end
    let sel = @a
    let filetype = &ft
    call luaeval('require("remnote").post(_A[1],_A[2])',[sel, filetype])
endfunction

function! GetFromRemnote()
    lua for k in pairs(package.loaded) do if k:match("^remnote") then package.loaded[k] = nil end end
    let filetype = &ft
    call luaeval('require("remnote").return_picker(_A[1])',[ filetype])
endfunction
