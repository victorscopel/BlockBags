-- Verify language selection, legacy profile labels and custom-name preservation.
local pt=A.locale=="ptBR" or A.locale=="ptPT"
assert(SLASH_BLOCKBAGS1=="/bb" and SLASH_BLOCKBAGS2=="/blockbags")
assert(A.L["Configurações"]==(pt and "Configurações" or (A.translations[A.locale] or {}).Settings or "Settings"))
assert(A.L["Inventário"]==(pt and "Inventário" or (A.translations[A.locale] or {}).Inventory or "Inventory"))
assert(A.L["Aba desta categoria"]==(pt and "Aba desta categoria" or (A.translations[A.locale] or {})["Category tab"] or "Category tab"))
assert(A.L["Favorito ausente da mochila."]==(pt and "Favorito ausente da mochila." or (A.translations[A.locale] or {})["Favorite missing from your backpack."] or "Favorite missing from your backpack."))
assert(A:DefaultCategoryName("equipment","Equipamentos")==A.L["Equipamentos"])
assert(A:DefaultCategoryName("equipment","Equipment")==A.L["Equipamentos"])
assert(A:DefaultCategoryName("equipment","My raid gear")=="My raid gear")
assert(A:DefaultCategoryName("custom_1","Equipamentos")=="Equipamentos")
assert(A:TabName({id="default",name="Principal"})==A.L["Principal"])
assert(A:TabName({id="default",name="Main"})==A.L["Principal"])
assert(A:TabName({id="default",name="My bags"})=="My bags")
assert(A:TabName({id="tab1",name="Principal"})=="Principal")
assert(A:CompileQuery("quality:epic upgrade:true slot:ring"))
assert(A:CompileQuery("qualidade:epico melhoria:sim slot:anel"))
local id=A.categories[1].id
local d=A:GetLayout()[id]; local previous=d.name
local exported=A:ExportProfile()
d.name="My equipment"; assert(A:CategoryName(id)=="My equipment"); d.name=previous
assert(A:ExportProfile()==exported)
local help=A.L["/bb — abrir; /bb edit — editar; /bb config — opções; /bb memory — diagnóstico; /bb reset — restaurar layout; /bb scale 0.85."]
assert(help:find("/bb config",1,true) and not help:find("/ab",1,true))
assert(A.closeButton:IsShown() and A.closeButton.level>A.decoration:GetFrameLevel() and A.closeButton.level>A.titleCaptionFrame:GetFrameLevel())
A.window:Show(); A.closeButton.scripts.OnClick(); assert(not A.window:IsShown())
print("Localization/close OK: "..A.locale..", /bb, translated defaults, custom names and exported data preserved, English/Portuguese filters, visible close button above border")

for locale,strings in pairs(A.translations) do
    for _,english in pairs(A.english) do assert(strings[english],locale..": missing "..english) end
end
local englishKey=A.english["Equipamentos"]
assert(A:DefaultCategoryName("equipment",A.translations.frFR[englishKey])==A.L["Equipamentos"])
assert(A:DefaultCategoryName("equipment",A.translations.esES[englishKey])==A.L["Equipamentos"])
print("Locale catalogs OK: full Spanish/esMX and French coverage, cross-language default names, English fallback")

local function formatTokens(value)
    local tokens={}
    for token in value:gsub("%%%%", ""):gmatch("%%[%d%.]*[sdif]") do tokens[#tokens+1]=token end
    return table.concat(tokens,"|")
end
for locale,strings in pairs(A.translations) do
    for _,english in pairs(A.english) do
        assert(formatTokens(strings[english])==formatTokens(english),locale..": mismatched format "..english)
        assert(not strings[english]:find("\\n",1,true),locale..": literal newline escape "..english)
    end
end
print("Localized format strings OK: placeholder order and real newlines")
