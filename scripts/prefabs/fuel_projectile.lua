local fuel_projectile_assets = {Asset("ANIM", "anim/poop.zip")}

local function OnHitPoop(inst, attacker, target)
    inst.target.components.fueled:TakeFuelItem(inst.item) -- 加燃料
    inst:Remove()
end

local function fuel_projectile_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.entity:AddPhysics()
    inst.Physics:SetMass(1)
    inst.Physics:SetFriction(0)
    inst.Physics:SetDamping(0)
    inst.Physics:SetCollisionGroup(COLLISION.CHARACTERS)
    inst.Physics:ClearCollisionMask()
    inst.Physics:CollidesWith(COLLISION.GROUND)
    inst.Physics:SetCapsule(0.2, 0.2)
    inst.Physics:SetDontRemoveOnSleep(true)

    inst:AddTag("projectile")
    inst:AddTag("NOCLICK")

    -- 默认bank build，在fuel-flingomatic中会重新覆盖，但这里如果不设置默认值会崩溃
    inst.AnimState:SetBank("log")
    inst.AnimState:SetBuild("log")
    inst.AnimState:PlayAnimation("idle", true)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("locomotor")

    inst:AddComponent("complexprojectile")

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    inst.target = nil -- 目标建筑
    inst.item = nil -- 燃料

    inst.components.complexprojectile:SetHorizontalSpeed(15)
    inst.components.complexprojectile:SetGravity(-25)
    inst.components.complexprojectile:SetLaunchOffset(Vector3(0, 2.35, 0))
    inst.components.complexprojectile:SetOnHit(OnHitPoop)

    return inst
end

return Prefab("fuel_projectile", fuel_projectile_fn, fuel_projectile_assets)
