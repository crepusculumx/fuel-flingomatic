local require = GLOBAL.require
local Vector3 = GLOBAL.Vector3

Assets = {Asset("ANIM", "anim/ui_chest_3x3.zip"), Asset("ATLAS", "images/inventoryimages/fuel_flingomatic.xml"),
          Asset("ATLAS", "minimap/fuel_flingomatic.xml")} --"atlas"小地图图标和建造栏图标能用

PrefabFiles = {"fuel_flingomatic", "fuel_projectile"}

local fuel_list = {
    ["cutgrass"] = true, -- 草
    ["log"] = true, -- 木头
    ["twigs"] = true, -- 小树枝
    ["charcoal"] = true, -- 木炭
    ["boards"] = true, -- 木板
    ["glommerfuel"] = true, -- 格罗姆燃料
    ["nightmarefuel"] = true -- 噩梦燃料（影灯）
} -- 能装的燃料

GLOBAL.STRINGS.NAMES.FUEL_FLINGOMATIC = "Fuel Flingomatic"
GLOBAL.STRINGS.RECIPE_DESC.FUEL_FLINGOMATIC = "Fuel your campfires automatically. Including the DARK one."

GLOBAL.STRINGS.CHARACTERS.GENERIC.DESCRIBE.FUEL_FLINGOMATIC = "It is SUPER useful!"

AddMinimapAtlas("minimap/fuel_flingomatic.xml") -- 小地图图标

AddRecipe("fuel_flingomatic", {GLOBAL.Ingredient("transistor", 2), GLOBAL.Ingredient("boards", 4)},
    GLOBAL.RECIPETABS.SCIENCE, -- 科学栏
    GLOBAL.TECH.SCIENCE_TWO, -- 要求二本
    "fuel_flingomatic_placer", -- placer 范围的圈
    2, -- min_spacing
    nil, -- nounlock
    nil, -- numtogive
    nil, -- builder_tag
    "images/inventoryimages/fuel_flingomatic.xml", -- atlas
    "fuel_flingomatic.tex")

local containers = require "containers"

local params = {}

local containers_widgetsetup_pf = containers.widgetsetup
function containers.widgetsetup(container, prefab, data, ...)
    local t = params[prefab or container.inst.prefab]
    if t ~= nil then
        for k, v in pairs(t) do
            container[k] = v
        end

        container:SetNumSlots(container.widget.slotpos ~= nil and #container.widget.slotpos)
    else
        containers_widgetsetup_pf(container, prefab, data, ...)
    end
end

params.fuel_flingomatic = {
    widget = {
        slotpos = {},
        animbank = "ui_chest_3x3", -- 动画
        animbuild = "ui_chest_3x3", -- 材质包
        pos = Vector3(0, 200, 0),
        side_align_tip = 160 -- 有可能是不关闭箱子查看的范围
    },
    type = "chest"
}

-- 可以放到箱子中的物品添加fuel标签
for k, v in pairs(fuel_list) do
    AddPrefabPostInit(k, function(inst)
        inst:AddTag("fuel")
    end)
end

function params.fuel_flingomatic.itemtestfn(container, item, slot)
    if item:HasTag("fuel") then
        return true
    end
    return false
end

-- 应该是箱子九宫格界面位置
for y = 2, 0, -1 do
    for x = 0, 2 do
        table.insert(params.fuel_flingomatic.widget.slotpos, Vector3(80 * x - 80 * 2 + 80, 80 * y - 80 * 2 + 80, 0))
    end
end

containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, params.fuel_flingomatic.widget.slotpos ~= nil and
                              #params.fuel_flingomatic.widget.slotpos or 0)

