-- pages
PageNames = {"Setup", "Control"}

function GetPages(props)
    local pages = {}
    for _, name in ipairs(PageNames) do
        table.insert(pages, {name = name})
    end
    return pages
end
