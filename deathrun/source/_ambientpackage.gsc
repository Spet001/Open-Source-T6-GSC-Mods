#include maps\mp\_utility;
#include common_scripts\utility;

init()
{
    level.ambient_modifier = [];
}

// =========================================================================
// LIMPEZA SEGURA DE ENTIDADES (NUNCA TOCA EM SPAWNS OU REGRAS)
// =========================================================================

PrepareAssets()
{
    // Deleta apenas modelos decorativos do chão para não estourar as 600 entidades
    models = getEntArray("script_model", "classname");
    for(i = 0; i < models.size; i++)
    {
        if(isDefined(models[i]) && models[i].origin[2] < 5000)
            models[i] delete();
    }

    brushes = getEntArray("script_brushmodel", "classname");
    for(i = 0; i < brushes.size; i++)
    {
        if(isDefined(brushes[i]) && brushes[i].origin[2] < 5000)
            brushes[i] delete();
    }
}

cleanArray(arr)
{
    if(!isDefined(arr)) return;
    for(i = 0; i < arr.size; i++)
    {
        if(isDefined(arr[i]))
            arr[i] delete();
    }
}

modelSpawner(origin, model, angles)
{
    obj = spawn("script_model", origin, 1);
    obj setModel(model);
    if(isDefined(angles))
        obj.angles = angles;
    return obj;
}

MakeDefaultPlatform(pos)
{
    self.platform = [];
    for(y = 0; y < 2; y++)
    {
        for(x = -2; x < 2; x++)
        {
            spawnPos = ((x * 135) + level.DeathRunspawnpoint[0], (y * 354) + pos, level.DeathRunspawnpoint[2]);
            part = modelSpawner(spawnPos, "p6_dockside_container_lrg_orange");
            self.platform[self.platform.size] = part;
        }
    }
}

MakeDefaultTrapBridge(pos)
{
    self.bridge = [];
    for(y = 0; y < 2; y++)
    {
        for(x = -2; x < 2; x++)
        {
            spawnPos = ((x * 135) + level.DeathRunspawnpoint[0], ((y + 2) * 354) + pos, level.DeathRunspawnpoint[2]);
            part = modelSpawner(spawnPos, "p6_dockside_container_lrg_orange");
            self.bridge[self.bridge.size] = part;
        }
    }
}

IsTouchingBridge(trap)
{
    foreach(box in trap.bridge)
    {
        if(self isTouching(box))
            return true;
    }

    bridgeOrigin = trap.bridge[0].origin;
    if(self.origin[1] >= (bridgeOrigin[1] - 177))
        return true;

    return false;
}

isTouchingPlatform(trap)
{
    foreach(box in trap.platform)
    {
        if(box isTouching(self))
            return true;
    }
    return false;
}

StillPlayersTrying(trap)
{
    playersLeft = false;
    foreach(player in level.Runners)
    {
        if(isAlive(player) && !player IsTouchingBridge(trap))
            playersLeft = true;
    }
    if(level.Runners.size < 1)
        return false;
    return playersLeft;
}

StillAllPlayersTrying(trap)
{
    foreach(player in level.Runners)
    {
        if(isAlive(player) && player IsTouchingBridge(trap) && player.origin[2] > 9500)
            return false;
    }
    if(level.Runners.size < 1)
        return false;
    return true;
}

// =========================================================================
// MAPEAMENTO DO PERCURSO NO CÉU (CARGO / MP_DOCKSIDE)
// =========================================================================

MapInit()
{
    PrepareAssets();

    level.DeathRunOrigin = (0, 0, 10000);
    level.DeathRunspawnpoint = level.DeathRunOrigin - (250, 0, 0);
    level.ActivatorSpawn = level.DeathRunspawnpoint + (270, 581, 140);
    level.NumberOfTriggers = 8;

    CreateMap();
}

CreateMap()
{
    level.DeathRunMapping = spawnStruct();
    level.DeathRunMapping.startareamodels = [];
    level.DeathRunMapping.collisions = [];
    level.DeathRunMapping.Flooring = [];
    level.DeathRunMapping.StartAreaFallers = [];
    level.DeathRunMapping.StartAreaOverhang = [];

    // Área inicial
    for(y = -354; y <= 0; y += 354)
    {
        level.DeathRunMapping.StartAreaFallers[level.DeathRunMapping.StartAreaFallers.size] = modelSpawner(level.DeathRunspawnpoint + (270, y, 25), "p6_dockside_container_lrg_orange");
        level.DeathRunMapping.StartAreaFallers[level.DeathRunMapping.StartAreaFallers.size] = modelSpawner(level.DeathRunspawnpoint + (270, y, 250), "p6_dockside_container_lrg_orange");
    }

    level.DeathRunMapping.startareamodels[level.DeathRunMapping.startareamodels.size] = modelSpawner(level.DeathRunspawnpoint + (270, 354, 25), "p6_dockside_container_lrg_orange");
    level.DeathRunMapping.startareamodels[level.DeathRunMapping.startareamodels.size] = modelSpawner(level.DeathRunspawnpoint + (270, 354, 250), "p6_dockside_container_lrg_orange");

    level.DeathRunMapping.StartAreaOverhang[0] = modelSpawner(level.DeathRunspawnpoint + (514.5, 242.804, 250), "p6_dockside_container_lrg_orange", (0, 90, 0));
    level.DeathRunMapping.StartAreaOverhang[1] = modelSpawner(level.DeathRunspawnpoint + (868.5, 242.804, 250), "p6_dockside_container_lrg_orange", (0, 90, 0));

    // Pisos
    for(x = -270; x <= 135; x += 135)
    {
        for(y = -354; y <= 0; y += 354)
        {
            level.DeathRunMapping.Flooring[level.DeathRunMapping.Flooring.size] = modelSpawner(level.DeathRunspawnpoint + (x, y, 0), "p6_dockside_container_lrg_orange");
        }
    }

    for(x = -270; x <= 135; x += 135)
    {
        for(y = 354; y <= 354; y += 354)
        {
            level.DeathRunMapping.startareamodels[level.DeathRunMapping.startareamodels.size] = modelSpawner(level.DeathRunspawnpoint + (x, y, 0), "p6_dockside_container_lrg_orange");
        }
    }

    for(y = -512; y <= 512; y += 512)
        level.DeathRunMapping.collisions[level.DeathRunMapping.collisions.size] = spawncollision("collision_clip_wall_512x512x10", "collider", (level.DeathRunspawnpoint + (202, y, 150)), (0, 90, 0));

    // Paredes
    for(y = -354; y <= 0; y += 354)
    {
        level.DeathRunMapping.StartAreaFallers[level.DeathRunMapping.StartAreaFallers.size] = modelSpawner(level.DeathRunspawnpoint + (-395, y, 117), "p6_dockside_container_lrg_orange");
        level.DeathRunMapping.StartAreaFallers[level.DeathRunMapping.StartAreaFallers.size] = modelSpawner(level.DeathRunspawnpoint + (-395, y, 250), "p6_dockside_container_lrg_orange");
    }

    limitY = (level.NumberOfTriggers * 4 * 354) + 354;
    for(y = 354; y <= limitY; y += 354)
    {
        level.DeathRunMapping.startareamodels[level.DeathRunMapping.startareamodels.size] = modelSpawner(level.DeathRunspawnpoint + (-395, y, 117), "p6_dockside_container_lrg_orange");
        level.DeathRunMapping.startareamodels[level.DeathRunMapping.startareamodels.size] = modelSpawner(level.DeathRunspawnpoint + (-395, y, 250), "p6_dockside_container_lrg_orange");
    }

    for(y = -354; y <= 0; y += 354)
        level.DeathRunMapping.StartAreaFallers[level.DeathRunMapping.StartAreaFallers.size] = modelSpawner(level.DeathRunspawnpoint + (405, y, 135), "p6_dockside_container_lrg_orange");

    for(y = 354; y <= limitY; y += 354)
        level.DeathRunMapping.startareamodels[level.DeathRunMapping.startareamodels.size] = modelSpawner(level.DeathRunspawnpoint + (405, y, 135), "p6_dockside_container_lrg_orange");

    for(y = -354; y <= 354; y += 354)
    {
        part = modelSpawner(level.DeathRunspawnpoint + (y, -500, 117), "p6_dockside_container_lrg_orange", (0, 90, 0));
        level.DeathRunMapping.StartAreaFallers[level.DeathRunMapping.StartAreaFallers.size] = part;

        part2 = modelSpawner(level.DeathRunspawnpoint + (y, -500, 250), "p6_dockside_container_lrg_orange", (0, 90, 0));
        level.DeathRunMapping.StartAreaFallers[level.DeathRunMapping.StartAreaFallers.size] = part2;
    }

    // Portões
    level.DeathRunGate = modelSpawner((-311.304, 175.304, 10136), "p6_metal_fence_gate", (0, 180, 0));
    level.DeathRunGateRight = modelSpawner((-114.304, 175.304, 10136), "p6_metal_fence", (0, 180, 0));
    level.DeathRunGateRight2 = modelSpawner((156.304, 175.304, 10144), "p6_metal_fence", (0, 180, 0));
    level.DeathRunGateLeft = modelSpawner((-508.304, 175.304, 10136), "p6_metal_fence", (0, 180, 0));

    level.DeathRunGateCollision = spawncollision("collision_clip_wall_256x256x10", "collider", level.DeathRunGate.origin, (0, 180, 0));
    spawncollision("collision_clip_wall_128x128x10", "collider", level.DeathRunGateRight.origin, (0, 180, 0));
    spawncollision("collision_clip_wall_128x128x10", "collider", level.DeathRunGateLeft.origin, (0, 180, 0));
}

OpenGates()
{
    level.DeathRunMapping.StartAreaFallers[0] moveZ(90, 0.05);
    level.DeathRunMapping.StartAreaFallers[2] moveZ(90, 0.05);
    wait 7.5;

    level.DeathRunGate moveX(-260, 1);
    level.DeathRunGateCollision moveX(-260, 1);

    foreach(player in level.players)
        player thread maps\mp\gametypes\_hud_message::hintMessage("THE DEATHRUN HAS STARTED");

    level thread GateCloseWatcher();
}

GateCloseWatcher()
{
    wait 15;
    level.DeathRunGate moveX(260, 10);
    level.DeathRunGateCollision moveX(260, 10);
    wait 10;

    foreach(model in level.DeathRunMapping.Flooring)
        model moveZ(-200, 1);
    wait 1.2;

    foreach(model in level.DeathRunMapping.Flooring)
        model physicsLaunch();
    foreach(model in level.DeathRunMapping.StartAreaFallers)
        model physicsLaunch();

    spawncollision("collision_clip_wall_128x128x10", "collider", (level.DeathRunGateRight2.origin + (135, 0, 0)), (0, 180, 0));
    level.DeathRunGateRight2 moveX(-135, 1);
    level.DeathRunMapping.StartAreaOverhang[0] moveX(-708, 2);
    level.DeathRunMapping.StartAreaOverhang[1] moveX(-708, 2);

    wait 5;
    foreach(model in level.DeathRunMapping.Flooring)
        model delete();
    foreach(model in level.DeathRunMapping.StartAreaFallers)
        model delete();
}

// =========================================================================
// SISTEMA DE ARMADILHAS E TRIGGERS
// =========================================================================

BuildTraps()
{
    level.DeathRunTraps = [];
    level.DeathRunTriggers = [];

    CreateTriggers();
    InitTrapList();

    level.DeathRunTraps = array_randomize(level.DeathRunTraps);

    for(i = 0; i < level.DeathRunTriggers.size && i < level.DeathRunTraps.size; i++)
        level.DeathRunTriggers[i] thread RegisterTrap(level.DeathRunTraps[i]);

    level.DeathRunTriggers[level.DeathRunTriggers.size - 1].trap thread WatchForWinner();
}

CreateTriggers()
{
    start = level.DeathRunspawnpoint + (0, 354, 0);

    for(i = 0; i < level.NumberOfTriggers * 4; i++)
    {
        level.DeathRunMapping.startareamodels[level.DeathRunMapping.startareamodels.size] = modelSpawner(start + (270, (i + 1) * 354, 25), "p6_dockside_container_lrg_orange");
        level.DeathRunMapping.startareamodels[level.DeathRunMapping.startareamodels.size] = modelSpawner(start + (270, (i + 1) * 354, 250), "p6_dockside_container_lrg_orange");
    }

    for(y = 256; y <= (level.NumberOfTriggers * 354 * 4); y += 512)
        level.DeathRunMapping.collisions[level.DeathRunMapping.collisions.size] = spawncollision("collision_clip_wall_512x512x10", "collider", (start + (202, y, 150)), (0, 90, 0));

    for(i = 0; i < level.NumberOfTriggers; i++)
    {
        triggerPos = start + (225, (((i * 4) + 1) * 354), 177);
        trig = modelSpawner(triggerPos, "t6_wpn_supply_drop_trap");
        trig.bombcase = modelSpawner(triggerPos + (0, 0, 15), "t6_wpn_briefcase_bomb_view", (0, 180, 0));
        level.DeathRunTriggers[i] = trig;
    }

    // Parede de encerramento
    for(y = -354; y <= 354; y += 354)
    {
        endY = (level.NumberOfTriggers * 354 * 4) + 244.5;
        level.DeathRunMapping.startareamodels[level.DeathRunMapping.startareamodels.size] = modelSpawner(level.DeathRunspawnpoint + (y, endY, 117), "p6_dockside_container_lrg_orange", (0, 90, 0));
        level.DeathRunMapping.startareamodels[level.DeathRunMapping.startareamodels.size] = modelSpawner(level.DeathRunspawnpoint + (y, endY, 250), "p6_dockside_container_lrg_orange", (0, 90, 0));
    }
}

InitTrapList()
{
    CreateTrap("Disappearing Floor Trap", ::FakeFloor_Activate, ::FakeFloor_Build);
    CreateTrap("Rocket Rain Trap", ::RocketTrap_Activate, ::RocketTrap_Build);
    CreateTrap("Checkerboard Trap", ::Checkerboard_Activate, ::Checkerboard_Build);
    CreateTrap("Falling Floor Trap", ::FallingFloor_Activate, ::FallingFloor_Build);
    CreateTrap("Mine Pit Trap", ::K9_Activate, ::K9_Build);
    CreateTrap("Barrel Trap", ::Barrel_Activate, ::Barrel_Build);
    CreateTrap("Fling Trap", ::FlingTrap_Activate, ::FlingTrap_Build);
    CreateTrap("Rotating Floor Trap", ::FloorRoller_Activate, ::FloorRoller_Build);
    CreateTrap("Bounce Trap", ::Bounce_Activate, ::Bounce_Build);
    CreateTrap("Grenade Drop Trap", ::NadeDrop_Activate, ::NadeDrop_Build);
}

CreateTrap(name, activation, buildmethod)
{
    trap = spawnStruct();
    trap.name = name;
    trap.activate = activation;
    trap.triggered = false;
    trap.positionTrap = buildmethod;
    level.DeathRunTraps[level.DeathRunTraps.size] = trap;
}

RegisterTrap(trap)
{
    if(isDefined(level.Activator))
        level.Activator thread TrapTriggerWatcher(self, trap);
    trap.trigger = self;
    trap thread [[trap.positionTrap]]();
    trap thread MakeDefaultTrapBridge(self.origin[1]);
    self.trap = trap;
}

TrapTriggerWatcher(trigger, trap)
{
    self endon("disconnect");
    while(!trap.triggered)
    {
        wait 0.1;
        if(distance(self.origin, trigger.origin) < 100)
        {
            self thread maps\mp\gametypes\_hud_message::hintMessage("Press [{+activate}] to trigger " + trap.name);
            if(self useButtonPressed())
            {
                trap.triggered = true;
                trigger setModel("t6_wpn_supply_drop_axis");
                trigger.bombcase setModel("prop_suitcase_bomb");
                trigger.bombcase.angles = (0, 270, 0);
                iPrintlnBold("^1Activator triggered: ^7" + trap.name);
                trap thread [[trap.activate]]();
                break;
            }
        }
    }
}

FakeFloor_Build()
{
    self.startOrigin = self.trigger.origin[1];
    self.platform = [];
    for(y = 0; y < 2; y++)
    {
        for(x = 0; x < 4; x++)
        {
            pos = ((x * 135) + level.DeathRunspawnpoint[0] - 270, (y * 354) + self.startOrigin, level.DeathRunspawnpoint[2]);
            self.platform[self.platform.size] = modelSpawner(pos, "p6_dockside_container_lrg_orange");
        }
    }
}

FakeFloor_Activate()
{
    foreach(model in self.platform)
        model delete();
    wait 3;
    [[self.positionTrap]]();
}

RocketTrap_Build()
{
    self MakeDefaultPlatform(self.trigger.origin[1]);
}

RocketTrap_Activate()
{
    trigY = self.trigger.origin[1];
    for(y = 0; y < (2 * 354); y += 120)
    {
        for(x = (-2 * 135); x < (2 * 135); x += 120)
        {
            start = ((x + level.DeathRunspawnpoint[0]), (y + trigY), level.DeathRunspawnpoint[2] + 250);
            magicBullet("usrpg_mp", start, (start - (0, 0, 50)), level.Activator);
            wait 0.08;
        }
    }
}

Checkerboard_Build()
{
    self.platform = [];
    x = -2;
    trigY = self.trigger.origin[1];
    for(y = 0; y < 2; y++)
    {
        if(y != 0) x = -1;
        for(; x < 2; x += 2)
        {
            pos = ((x * 135) + level.DeathRunspawnpoint[0], (y * 354) + trigY, level.DeathRunspawnpoint[2]);
            self.platform[self.platform.size] = modelSpawner(pos, "p6_dockside_container_lrg_orange");
        }
    }
}

Checkerboard_Activate()
{
    self.platform[0] moveX(135, 0.5);
    self.platform[1] moveX(135, 0.5);
    self.platform[2] moveX(-135, 0.5);
    self.platform[3] moveX(-135, 0.5);
    wait 0.6;
    self.platform[0] moveX(-135, 0.5);
    self.platform[1] moveX(-135, 0.5);
    self.platform[2] moveX(135, 0.5);
    self.platform[3] moveX(135, 0.5);
}

FallingFloor_Build()
{
    self MakeDefaultPlatform(self.trigger.origin[1]);
}

FallingFloor_Activate()
{
    foreach(part in self.platform)
        part moveZ(-200, 0.5);
    wait 0.75;
    foreach(part in self.platform)
        part physicsLaunch();
    wait 4;
    foreach(part in self.platform)
        part delete();
    [[self.positionTrap]]();
}

K9_Build()
{
    self MakeDefaultPlatform(self.trigger.origin[1]);
}

K9_Activate()
{
    foreach(part in self.platform)
        part moveZ(-135, 0.25);
    wait 0.3;

    self.mines = [];
    foreach(box in self.platform)
    {
        mine = modelSpawner(box.origin + (0, 0, 137), "t6_wpn_c4_world");
        self.mines[self.mines.size] = mine;
        mine thread MineTouchExplode();
    }
    wait 4;
    cleanArray(self.mines);
    foreach(part in self.platform)
        part moveZ(135, 0.25);
}

MineTouchExplode()
{
    self endon("death");
    while(isDefined(self))
    {
        wait 0.1;
        foreach(player in level.Runners)
        {
            if(isAlive(player) && distance(player.origin, self.origin) < 65)
            {
                magicBullet("usrpg_mp", self.origin + (0, 0, 10), player.origin, level.Activator);
                return;
            }
        }
    }
}

Barrel_Build()
{
    trigY = self.trigger.origin[1];
    self MakeDefaultPlatform(trigY);
    coords = (level.DeathRunspawnpoint[0], trigY + 177, level.DeathRunspawnpoint[2] + 240);
    self.DeathRun_BarrelTrap = [];

    for(ext = 0; ext < 3; ext++)
    {
        self.DeathRun_BarrelTrap[self.DeathRun_BarrelTrap.size] = modelSpawner(coords + (100, -100 + ext * 100, 135), "com_barrel_biohazard_rust", (randomInt(360), randomInt(360), randomInt(360)));
        self.DeathRun_BarrelTrap[self.DeathRun_BarrelTrap.size] = modelSpawner(coords + (-80, -100 + ext * 100, 135), "com_barrel_biohazard_rust", (randomInt(360), randomInt(360), randomInt(360)));
        self.DeathRun_BarrelTrap[self.DeathRun_BarrelTrap.size] = modelSpawner(coords + (-190, -100 + ext * 100, 135), "com_barrel_biohazard_rust", (randomInt(360), randomInt(360), randomInt(360)));
    }
}

Barrel_Activate()
{
    for(ext = 0; ext < self.DeathRun_BarrelTrap.size; ext++)
    {
        if(isDefined(self.DeathRun_BarrelTrap[ext]))
        {
            self.DeathRun_BarrelTrap[ext] physicsLaunch();
            self.DeathRun_BarrelTrap[ext] thread BarrelDamageWatcher();
        }
    }
}

BarrelDamageWatcher()
{
    self endon("death");
    while(isDefined(self))
    {
        wait 0.05;
        foreach(dude in level.Runners)
        {
            if(isAlive(dude) && dude isTouching(self))
            {
                dude doDamage(dude.health + 1, dude.origin, level.Activator, self, "none", "MOD_HIT_BY_OBJECT", 0, "supplydrop_mp");
                dude playSound("phy_impact_supply");
            }
        }
    }
}

FlingTrap_Build()
{
    self MakeDefaultPlatform(self.trigger.origin[1]);
}

FlingTrap_Activate()
{
    for(i = 0; i < self.platform.size; i++)
    {
        roll = (i % 2 == 0) ? 180 : -180;
        self.platform[i] rotateRoll(roll, 0.8);
    }
    wait 2.0;
    for(i = 0; i < self.platform.size; i++)
    {
        roll = (i % 2 == 0) ? -180 : 180;
        self.platform[i] rotateRoll(roll, 0.8);
    }
}

FloorRoller_Build()
{
    self MakeDefaultPlatform(self.trigger.origin[1]);
}

FloorRoller_Activate()
{
    for(r = 0; r < 4; r++)
    {
        for(i = 0; i < self.platform.size; i++)
        {
            yaw = (i % 2 == 0) ? 360 : -360;
            self.platform[i] rotateYaw(yaw, 2.0);
        }
        wait 2.0;
    }
}

Bounce_Build()
{
    self MakeDefaultPlatform(self.trigger.origin[1]);
}

Bounce_Activate()
{
    foreach(box in self.platform)
        box moveZ(450, 0.25);
    wait 0.3;

    foreach(player in level.Runners)
    {
        if(isAlive(player) && player isTouchingPlatform(self))
        {
            player setVelocity(player getVelocity() + (-200, -200, 850));
            player doDamage(player.health + 1, player.origin, level.Activator);
        }
    }

    wait 0.5;
    foreach(box in self.platform)
        box moveZ(-450, 2.0);
}

NadeDrop_Build()
{
    self MakeDefaultPlatform(self.trigger.origin[1]);
}

NadeDrop_Activate()
{
    trigY = self.trigger.origin[1];
    coords = (level.DeathRunspawnpoint[0], trigY, level.DeathRunspawnpoint[2] + 250);
    for(i = 0; i < 20; i++)
    {
        time = 1.5 + (i / 10.0);
        magicBullet("frag_grenade_mp", coords + (randomIntRange(-100, 100), randomIntRange(-100, 100), 0), coords - (0, 0, 50), level.Activator);
        wait 0.1;
    }
}

// =========================================================================
// CONDIÇÃO FINAL: ARENA DO ACTIVATOR
// =========================================================================

WatchForWinner()
{
    while(!level.DeathRunInProgress)
        wait 1.0;

    while(StillAllPlayersTrying(self))
        wait 1.5;

    // Se estiver jogando sozinho, não finaliza a partida
    if(level.players.size <= 1)
        return;

    foreach(player in level.Runners)
    {
        if(isAlive(player))
        {
            player enableWeapons();
            player giveWeapon("knife_mp");
            player switchToWeapon("knife_mp");
            player setMoveSpeedScale(1.8);
        }
    }

    if(isDefined(level.Activator))
    {
        level.Activator setMoveSpeedScale(0.8);
        level.Activator disableInvulnerability();
    }

    foreach(col in level.DeathRunMapping.collisions)
    {
        if(isDefined(col))
            col delete();
    }

    foreach(player in level.players)
    {
        if(isDefined(player.runner) && player.runner)
            player thread maps\mp\gametypes\_hud_message::hintMessage("^2KILL THE ACTIVATOR!");
        else
            player thread maps\mp\gametypes\_hud_message::hintMessage("^1RUNNERS REACHED THE END! DEFEND YOURSELF!");
    }

    while(isDefined(level.Activator) && isAlive(level.Activator))
        wait 1.0;

    iPrintlnBold("^2RUNNERS WON THE DEATHRUN!");
    wait 2.0;
    maps\mp\gametypes\_globallogic::forceEnd(0);
}