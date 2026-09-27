#include maps\mp\_utility;
#include common_scripts\utility;

init()
{
    level.ambient_modifier = [];
}

// =========================================================================
// MOTOR FÍSICO DO FORGE & OBJETOS DINÂMICOS
// =========================================================================

spawnScriptModel(model, origin, angles)
{
    ent = spawn("script_model", origin);
    if(isDefined(angles))
        ent.angles = angles;
    ent setModel(model);
    return ent;
}

// Desativa triggers de morte e kill barriers em todo o mapa
disableDeathBarriers()
{
    level.deathBarriersDisabled = true;
    triggers = getEntArray("trigger_hurt", "classname");
    for(i = 0; i < triggers.size; i++)
        triggers[i].origin = (0, 0, 999999);
}

createWall(start, end, invisible)
{
    distXY = distance((start[0], start[1], 0), (end[0], end[1], 0));
    distZ  = abs(end[2] - start[2]);

    blocksH = int(ceil(distXY / 70.0));
    blocksV = int(ceil(distZ / 36.0));
    if(blocksH < 1) blocksH = 1;
    if(blocksV < 1) blocksV = 1;

    deltaStep = (end - start) / blocksH;
    deltaZ = (0, 0, 36);

    dir = vectorToAngles(end - start);
    wallAngle = (0, dir[1] + 90, 0);

    for(v = 0; v < blocksV; v++)
    {
        for(h = 0; h < blocksH; h++)
        {
            pos = start + (deltaStep * h) + (deltaZ * v);
            part = spawnScriptModel(level.supplyDropModel, pos, wallAngle);
            if(isDefined(invisible) && invisible)
                part hide();
        }
    }
}

createRamp(start, end, invisible)
{
    dist = distance(start, end);
    blocks = int(ceil(dist / 32.0));
    if(blocks < 1) blocks = 1;

    step = (end - start) / blocks;
    angles = vectorToAngles(end - start);

    for(i = 0; i <= blocks; i++)
    {
        pos = start + (step * i);
        part = spawnScriptModel(level.supplyDropModel, pos, angles);
        if(isDefined(invisible) && invisible)
            part hide();
    }
}

createGrid(corner1, corner2, angle, invisible)
{
    width = distance((corner1[0], 0, 0), (corner2[0], 0, 0));
    length = distance((0, corner1[1], 0), (0, corner2[1], 0));

    rows = int(ceil(width / 40.0));
    cols = int(ceil(length / 70.0));
    if(rows < 1) rows = 1;
    if(cols < 1) cols = 1;

    stepX = (corner2[0] - corner1[0]) / rows;
    stepY = (corner2[1] - corner1[1]) / cols;

    for(r = 0; r <= rows; r++)
    {
        for(c = 0; c <= cols; c++)
        {
            pos = corner1 + (stepX * r, stepY * c, 0);
            part = spawnScriptModel(level.supplyDropModel, pos, angle);
            if(isDefined(invisible) && invisible)
                part hide();
        }
    }
}

createDoor(openPos, closePos, moveTime, angle, width, height, hp, triggerRadius)
{
    doorCenter = spawnScriptModel("tag_origin", closePos, angle);
    doorCenter.openPos = openPos;
    doorCenter.closePos = closePos;
    doorCenter.moveTime = moveTime;
    doorCenter.maxHP = hp;
    doorCenter.hp = hp;
    doorCenter.state = "closed";
    doorCenter.radius = triggerRadius;
    doorCenter.isMoving = false;

    offsetStep = 32;
    startX = 0 - ((width - 1) * offsetStep) / 2;

    for(w = 0; w < width; w++)
    {
        for(h = 0; h < height; h++)
        {
            localOffset = (startX + (w * offsetStep), 0, h * 36);
            part = spawnScriptModel("t6_wpn_supply_drop_axis", closePos + localOffset, angle);
            part linkTo(doorCenter);
        }
    }

    doorCenter thread doorWatcher();
}

doorWatcher()
{
    level endon("game_ended");

    for(;;)
    {
        wait 0.1;
        foreach(player in level.players)
        {
            if(!isAlive(player)) continue;

            if(distance(player.origin, self.origin) <= self.radius)
            {
                if(player.status == "human" && player useButtonPressed())
                {
                    if(!self.isMoving && self.state != "broken")
                    {
                        self.isMoving = true;
                        if(self.state == "closed")
                        {
                            self moveTo(self.openPos, self.moveTime);
                            self playSound("mpl_drone_door_open");
                            wait self.moveTime;
                            self.state = "open";
                        }
                        else
                        {
                            self moveTo(self.closePos, self.moveTime);
                            self playSound("mpl_drone_door_close");
                            wait self.moveTime;
                            self.state = "closed";
                        }
                        self.isMoving = false;
                        wait 0.4;
                    }
                    else if(self.state == "broken")
                    {
                        repairCost = 200;
                        if(player.money >= repairCost)
                        {
                            player.money -= repairCost;
                            self.hp = self.maxHP;
                            self.state = "closed";
                            self moveTo(self.closePos, self.moveTime);
                            player iPrintlnBold("^2Door Repaired! (-$200)");
                            wait self.moveTime;
                        }
                    }
                }

                if(player.status == "zombie" && self.state == "closed" && player attackButtonPressed())
                {
                    self.hp -= 6;
                    player.money += 15;
                    self playSound("mpl_drone_door_close");

                    if(self.hp <= 0)
                    {
                        self.state = "broken";
                        self moveTo(self.openPos, 0.4);
                        iPrintlnBold("^1A defensive door was DESTROYED!");
                    }
                    wait 0.35;
                }
            }
        }
    }
}

createZipline(start, end, travelTime, isBidirectional)
{
    zip = spawnStruct();
    zip.start = start;
    zip.end = end;
    zip.time = travelTime;
    zip.twoWay = isBidirectional;

    spawnScriptModel("mp_flag_green", start, (0, 0, 0));
    spawnScriptModel(isBidirectional ? "mp_flag_green" : "mp_flag_red", end, (0, 0, 0));

    zip thread ziplineWatcher();
}

ziplineWatcher()
{
    level endon("game_ended");

    for(;;)
    {
        wait 0.05;
        foreach(player in level.players)
        {
            if(!isAlive(player) || player.usingZipline) continue;

            if(distance(player.origin, self.start) < 60 && player useButtonPressed())
                player thread rideZipline(self.start, self.end, self.time);
            else if(self.twoWay && distance(player.origin, self.end) < 60 && player useButtonPressed())
                player thread rideZipline(self.end, self.start, self.time);
        }
    }
}

rideZipline(from, to, duration)
{
    self endon("disconnect");
    self endon("death");

    self.usingZipline = true;
    mover = spawnScriptModel("tag_origin", from, (0, 0, 0));
    self playerLinkTo(mover);
    mover moveTo(to, duration, 0.1, 0.1);

    wait duration;

    self unlink();
    mover delete();
    self.usingZipline = false;
}

createFlag(start, target, isHidden, isBidirectional)
{
    f1 = spawnScriptModel("mp_flag_neutral", start, (0, 0, 0));
    f2 = spawnScriptModel("mp_flag_neutral", target, (0, 0, 0));

    if(isHidden)
    {
        f1 hide();
        f2 hide();
    }

    level thread flagWatcher(f1, f2, isBidirectional);
}

flagWatcher(f1, f2, isTwoWay)
{
    level endon("game_ended");
    for(;;)
    {
        wait 0.1;
        foreach(player in level.players)
        {
            if(!isAlive(player)) continue;

            if(distance(player.origin, f1.origin) < 50)
            {
                player setOrigin(f2.origin + (0, 0, 15));
                wait 0.6;
            }
            else if(isTwoWay && distance(player.origin, f2.origin) < 50)
            {
                player setOrigin(f1.origin + (0, 0, 15));
                wait 0.6;
            }
        }
    }
}

createMysteryBox(origin, angle, price)
{
    box = spawnScriptModel("t6_wpn_supply_drop_axis", origin, angle);
    box.price = price;
    box.inUse = false;
    box thread mysteryBoxWatcher();
}

mysteryBoxWatcher()
{
    level endon("game_ended");
    for(;;)
    {
        wait 0.1;
        foreach(player in level.players)
        {
            if(!isAlive(player) || self.inUse) continue;

            if(distance(player.origin, self.origin) < 65 && player useButtonPressed())
            {
                if(player.status == "human" && player.money >= self.price)
                {
                    player.money -= self.price;
                    self.inUse = true;
                    self thread dispenseRandomWeapon(player);
                }
                else if(player.status == "human")
                {
                    player iPrintlnBold("^1Need $" + self.price + " for Mystery Box!");
                }
                wait 0.4;
            }
        }
    }
}

dispenseRandomWeapon(player)
{
    weaponPool = array(
        "mp7_mp", "pdw57_mp", "vector_mp", "insas_mp",
        "tar21_mp", "an94_mp", "870mcs_mp", "dsr50_mp",
        "minigun_wager_mp", "m32_wager_mp", "knife_ballistic_mp"
    );

    weapon = weaponPool[randomInt(weaponPool.size)];
    wait 1.2;

    if(isDefined(player) && isAlive(player))
    {
        currentWeapon = player getCurrentWeapon();
        player takeWeapon(currentWeapon);
        player giveWeapon(weapon);
        player switchToWeapon(weapon);
        player giveMaxAmmo(weapon);
        player iPrintlnBold("^2Mystery Box: ^7" + weapon);
    }

    self.inUse = false;
}

// =========================================================================
// SPAWNABLES DE SHOP (BUNKER, TELEPORTE OUT OF MAP)
// =========================================================================

spawnBunkerAtPlayer(player)
{
    fwd = anglesToForward(player.angles);
    center = player.origin + vectorScale(fwd, 90);

    p1 = center + (-80, -80, 0);
    p2 = center + (80, -80, 0);
    p3 = center + (80, 80, 0);
    p4 = center + (-80, 80, 0);

    createWall(p1, p2, false);
    createWall(p2, p3, false);
    createWall(p4, p1, false);

    doorClose = (p4 + p3) * 0.5;
    doorOpen = doorClose + (0, 0, 75);
    createDoor(doorOpen, doorClose, 1.2, player.angles, 3, 2, 80, 70);

    roofCenter = center + (0, 0, 75);
    spawnScriptModel(level.supplyDropModel, roofCenter, (0, 0, 0));
    spawnScriptModel(level.supplyDropModel, roofCenter + (35, 0, 0), (0, 0, 0));
    spawnScriptModel(level.supplyDropModel, roofCenter + (-35, 0, 0), (0, 0, 0));

    player iPrintlnBold("^2Personal Bunker Deployed!");
}

spawnOutOfMapTeleport(player)
{
    disableDeathBarriers();

    entrance = player.origin;
    exitPos = player.origin + (0, 0, 2200);

    spawnScriptModel(level.supplyDropModel, exitPos + (-35, 0, -10), (0, 0, 0));
    spawnScriptModel(level.supplyDropModel, exitPos + (35, 0, -10), (0, 0, 0));
    spawnScriptModel(level.supplyDropModel, exitPos + (0, -35, -10), (0, 0, 0));
    spawnScriptModel(level.supplyDropModel, exitPos + (0, 35, -10), (0, 0, 0));

    createFlag(entrance, exitPos + (0, 0, 15), false, true);
    iPrintlnBold("^3A Public Out-Of-Bounds Teleporter was Opened!");
}

// =========================================================================
// CONFIGURAÇÕES DOS MAPAS
// =========================================================================

setupCustomMap()
{
    disableDeathBarriers();
    map = getDvar("mapname");

    switch(map)
    {
        case "mp_nuketown_2020":
            buildNuketown();
            break;
        case "mp_hijacked":
            buildHijacked();
            break;
        case "mp_express":
            buildExpress();
            break;
        case "mp_dockside":
            buildCargo();
            break;
    }
}

buildNuketown()
{
    createWall((402, -1968, 320), (80, -1968, 320.01), false);
    createWall((402, -1968, 390), (80, -1968, 390.01), false);
    createDoor((-166, -1968, 330), (20, -1968, 330), 1.5, (90, 90, 0), 5, 2, 35, 90);
    createMysteryBox((-320, -2198, 308), (0, 180, 0), 150);
    createZipline((-240, -589, -60), (-240, -1782, 308), 2.0, false);
    createFlag((-413, -2225, 170), (-1846, 930, -50), true, false);
}

buildHijacked()
{
    createDoor((-889.721, 185.118, 20.125), (-1056.59, 185.118, 20.125), 3, (90, 90, 0), 3, 2, 40, 80);
    createZipline((-1565.27, 44.0073, 92.125), (-2753.54, -336.392, 159.294), 4.0, true);
    createMysteryBox((-2512.75, 1284.45, 159.294), (0, 90, 0), 50);
}

buildExpress()
{
    createMysteryBox((-3494, -3633, 428), (0, 73, 0), 125);
    createZipline((-4313, -3273, -30), (2226, 1050, -120), 2.0, true);
    createDoor((2849, -696, -120), (3151, -20, -100), 2, (90, 90, 0), 3, 2, 30, 80);
}

buildCargo()
{
    createMysteryBox((-4350, 380, -195), (0, 90, 0), 150);
    createZipline((-4475, 2018, -195), (-4475, 2018, 715), 3.0, true);
}