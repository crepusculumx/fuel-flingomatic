require "prefabutil"

local easing = require("easing")

local assets = {Asset("ANIM", "anim/fuel_flingomatic.zip"), Asset("IMAGE", "minimap/fuel_flingomatic.tex"),
                Asset("ATLAS", "minimap/fuel_flingomatic.xml"), Asset("ANIM", "anim/ui_chest_3x3.zip")}

local prefabs = {"fuel_projectile", "collapse_small"}

local LIGHT_FUEL_LIST = {
    ["firepit"] = {
        ["cutgrass"] = true,
        ["log"] = true,
        ["boards"] = true,
        ["twigs"] = true,
        ["charcoal"] = true,
        ["glommerfuel"] = true
    },
    ["coldfirepit"] = {
        ["cutgrass"] = true,
        ["log"] = true,
        ["boards"] = true,
        ["twigs"] = true,
        ["charcoal"] = true,
        ["glommerfuel"] = true
    },
    ["nightlight"] = {
        ["nightmarefuel"] = true
    }
}

local FERTILIZATION_RANGE = 20
local N_MAX = 10
local T_MAX = 3
local CHECK_FERT_TIME = 5


local function onopen(inst)
    if inst:HasTag("burnt") then
        return
    end

    if inst.components.machine and inst.components.machine.ison == true then
        inst.AnimState:PlayAnimation("open")
        inst.SoundEmitter:PlaySound("dontstarve/common/together/portable/spicer/lid_open")
    end
    inst.isopen = true
end

local function onclose(inst)
    if inst:HasTag("burnt") then
        return
    end

    if inst.components.machine and inst.components.machine.ison == true then
        inst.AnimState:PlayAnimation("close")
        inst.AnimState:PushAnimation("idle", true)
        inst:DoTaskInTime(0.4, function()
            inst.SoundEmitter:PlaySound("dontstarve/common/together/portable/spicer/lid_close")
        end)
    end
    inst.isopen = false
end

local function onturnon(inst)
    if inst:HasTag("burnt") then
        return
    end

    if inst.isopen == false then
        inst.AnimState:PlayAnimation("close")
        inst.AnimState:PushAnimation("idle", true)
        inst:DoTaskInTime(0.4, function()
            inst.SoundEmitter:PlaySound("dontstarve/common/together/portable/spicer/lid_close")
        end)
    end
    inst.components.machine.ison = true
end

local function onturnoff(inst)
    if inst:HasTag("burnt") then
        return
    end

    if inst.isopen == false then
        inst.AnimState:PlayAnimation("open")
        inst.SoundEmitter:PlaySound("dontstarve/common/together/portable/spicer/lid_open")
    end
    inst.components.machine.ison = false
end

local function OnBurnt(inst)
    DefaultBurntStructureFn(inst)
    inst:RemoveComponent("machine")
end

local function onhammered(inst, worker)
    if inst.components.burnable ~= nil and inst.components.burnable:IsBurning() then
        inst.components.burnable:Extinguish()
    end
    inst.SoundEmitter:KillSound("firesuppressor_idle")
    inst.components.lootdropper:DropLoot()
    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("wood")
    inst:Remove()
end

local function onhit(inst, worker)
    if not inst:HasTag("burnt") then
        inst.components.container:Close()
        inst.AnimState:PlayAnimation("hit")
        inst.components.container:DropEverything()
        inst.components.machine.ison = true
        -- TODO: A hit animation for it when its closed and when its open, but not now
    end
end

local function onsave(inst, data)
    if inst:HasTag("burnt") or (inst.components.burnable ~= nil and inst.components.burnable:IsBurning()) then
        data.burnt = true
    end
end

local function onload(inst, data)
    if data ~= nil and data.burnt and inst.components.burnable ~= nil and inst.components.burnable.onburnt ~= nil then
        inst.components.burnable.onburnt(inst)
    end
end

local function onbuilt(inst)
    inst.SoundEmitter:PlaySound("dontstarve_DLC001/common/firesupressor_craft")
    inst.AnimState:PlayAnimation("place")
    inst.AnimState:PushAnimation("idle", true)
end

local function LaunchProjectile(inst, target, item)
    local waittime = 0.15
    local x, y, z = inst.Transform:GetWorldPosition() -- 建筑坐标

    local targetpos = target:GetPosition()

    local projectile = SpawnPrefab("fuel_projectile")
    projectile.Transform:SetPosition(x, y, z)
    projectile.AnimState:SetScale(0.5, 0.5)
    projectile.AnimState:SetBank(item.prefab)
    projectile.AnimState:SetBuild(item.prefab)
    projectile.target = target
    projectile.item = item

    local dx = targetpos.x - x
    local dz = targetpos.z - z
    local rangesq = dx * dx + dz * dz
    local maxrange = FERTILIZATION_RANGE
    local speed = easing.linear(rangesq, 20, 3, maxrange * maxrange)
    projectile.components.complexprojectile:SetHorizontalSpeed(speed)
    projectile.components.complexprojectile:SetGravity(-25)
    projectile.components.complexprojectile:Launch(targetpos, inst, inst)
    repeat

    until projectile ~= nil
end

local function CheckForAddFuel(inst)

    local function findFuelAndAdd(target)
        for k, item in pairs(inst.components.container.slots) do
            local function itemCanAndShouldFuel()

                if LIGHT_FUEL_LIST[target.prefab][item.prefab] == nil then
                    return false
                end

                -- 小于50%必填火
                if target.components.fueled:GetPercent() < 0.5 then
                    return true
                end
                -- 大于50%不亏才填
                local wetmult = item:GetIsWet() and TUNING.WET_FUEL_PENALTY or 1
                local delta = item.components.fuel.fuelvalue * target.components.fueled.bonusmult * wetmult
                if (delta + target.components.fueled.currentfuel - target.components.fueled.maxfuel) /
                    target.components.fueled.maxfuel < 0.1 then
                    return true
                end
                return false
            end

            if itemCanAndShouldFuel() then
                local projectileItem = item.components.stackable:Get(1)
                LaunchProjectile(inst, target, projectileItem)
                return -- 每轮先只添加一个燃料，否则弹幕在空中机器会试图继续添加燃料，暂时无法解决异步问题
            end
        end
    end

    -- 烧毁、开启箱子、机器关闭无效
    if inst:HasTag("burnt") or inst.isopen or inst.components.machine.ison == false then
        return
    end
    -- 夜晚才工作
    if not TheWorld.state.isnight then
        return
    end

    local x, y, z = inst.Transform:GetWorldPosition()

    -- 遍历范围内全部物品
    for k, target in ipairs(TheSim:FindEntities(x, y, z, inst.fertilization_range)) do
        local function targetCanBeFueled()
            if LIGHT_FUEL_LIST[target.prefab] == nil then
                return false
            end
            return true
        end
        if targetCanBeFueled() then
            findFuelAndAdd(target)
        end
    end
end

--------------------------------------------------------------------------
local PLACER_SCALE = 1.77

local function OnEnableHelper(inst, enabled)
    if enabled then
        if inst.helper == nil then
            inst.helper = CreateEntity()

            --[[Non-networked entity]]
            inst.helper.entity:SetCanSleep(false)
            inst.helper.persists = false

            inst.helper.entity:AddTransform()
            inst.helper.entity:AddAnimState()

            inst.helper:AddTag("CLASSIFIED")
            inst.helper:AddTag("NOCLICK")
            inst.helper:AddTag("placer")

            inst.helper.Transform:SetScale(PLACER_SCALE, PLACER_SCALE, PLACER_SCALE)

            inst.helper.AnimState:SetBank("poop_flingomatic")
            inst.helper.AnimState:SetBuild("poop_flingomatic")
            inst.helper.AnimState:PlayAnimation("placer")
            inst.helper.AnimState:SetLightOverride(1)
            inst.helper.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
            inst.helper.AnimState:SetLayer(LAYER_BACKGROUND)
            inst.helper.AnimState:SetSortOrder(1)
            inst.helper.AnimState:SetAddColour(0, .2, .5, 0)

            inst.helper.entity:SetParent(inst.entity)
        end
    elseif inst.helper ~= nil then
        inst.helper:Remove()
        inst.helper = nil
    end
end

--------------------------------------------------------------------------

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    local minimap = inst.entity:AddMiniMapEntity()
    minimap:SetIcon("fuel_flingomatic.tex")

    MakeObstaclePhysics(inst, 0.5)

    inst.AnimState:SetBank("poop_flingomatic")
    inst.AnimState:SetBuild("poop_flingomatic")
    inst.AnimState:PlayAnimation("idle", true)
    --    inst.AnimState:OverrideSymbol("swap_meter", "firefighter_meter", "10")

    inst:AddTag("structure")

    -- Dedicated server does not need deployhelper
    if not TheNet:IsDedicated() then
        inst:AddComponent("deployhelper")
        inst.components.deployhelper.onenablehelper = OnEnableHelper
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.isopen = false

    inst:ListenForEvent("onbuilt", onbuilt)

    inst:WatchWorldState("isnight", onIsNight) -- 监听黑夜
    inst:WatchWorldState("isday", onIsDay) -- 监听白天
    inst.isNight = false

    inst:AddComponent("inspectable")
    --  inst.components.inspectable.getstatus = getstatus

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("fuel_flingomatic")
    inst.components.container.onopenfn = onopen
    inst.components.container.onclosefn = onclose

    inst:AddComponent("machine")
    inst.components.machine.turnonfn = onturnon
    inst.components.machine.turnofffn = onturnoff
    inst.components.machine.cooldowntime = 0.5
    inst.components.machine.ison = true

    inst:AddComponent("lootdropper")
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)
    inst.components.workable:SetOnFinishCallback(onhammered)
    inst.components.workable:SetOnWorkCallback(onhit)

    MakeMediumBurnable(inst, nil, nil, true)
    MakeMediumPropagator(inst)
    inst.components.burnable:SetOnBurntFn(OnBurnt)

    inst.fertilization_range = FERTILIZATION_RANGE
    inst._isupdating = inst:DoPeriodicTask(CHECK_FERT_TIME, CheckForAddFuel, 5)

    inst.LaunchProjectile = LaunchProjectile

    inst.OnSave = onsave
    inst.OnLoad = onload
    -- inst.OnLoadPostPass = OnLoadPostPass

    inst.components.machine:TurnOn()

    MakeHauntableWork(inst) -- 可以作祟

    return inst
end

local function placer_postinit_fn(inst)
    -- Show the flingo placer on top of the flingo range ground placer

    local placer2 = CreateEntity()

    --[[Non-networked entity]]
    placer2.entity:SetCanSleep(false)
    placer2.persists = false

    placer2.entity:AddTransform()
    placer2.entity:AddAnimState()

    placer2:AddTag("CLASSIFIED")
    placer2:AddTag("NOCLICK")
    placer2:AddTag("placer")

    local s = 1 / PLACER_SCALE
    placer2.Transform:SetScale(s, s, s)

    placer2.AnimState:SetBank("poop_flingomatic")
    placer2.AnimState:SetBuild("poop_flingomatic")
    placer2.AnimState:PlayAnimation("idle", false)
    placer2.AnimState:SetLightOverride(1)

    placer2.entity:SetParent(inst.entity)

    inst.components.placer:LinkEntity(placer2)
end

return Prefab("fuel_flingomatic", fn, assets, prefabs),
    MakePlacer("fuel_flingomatic_placer", "poop_flingomatic", "poop_flingomatic", "placer", true, nil, nil,
        PLACER_SCALE, nil, nil, placer_postinit_fn)
