#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes\_hud_util;
#include maps\mp\gametypes\_hud_message;

init()
{
    // Partida infinita em FFA ou TDM
    setDvar("scr_dm_timelimit", "0");
    setDvar("scr_dm_scorelimit", "0");
    setDvar("scr_tdm_timelimit", "0");
    setDvar("scr_tdm_scorelimit", "0");
    setDvar("scr_team_fftype", "1");
    setDvar("scr_friendlyfire", "1");
    level.friendlyfire = 1;

    precacheItem("minigun_wager_mp");
    precacheItem("m32_wager_mp");
    precacheItem("knife_mp");
    precacheItem("knife_ballistic_mp");
    precacheItem("hatchet_mp");
    precacheItem("satchel_charge_mp");

    models = array(
        "t6_wpn_supply_drop_ally",
        "t6_wpn_supply_drop_axis",
        "mp_flag_green",
        "mp_flag_red",
        "mp_flag_neutral"
    );
    for(i = 0; i < models.size; i++)
        precacheModel(models[i]);

    level.supplyDropModel = "t6_wpn_supply_drop_ally";
    level.gameEnded = false;
    level.zombieficationTime = 15;
    level.survivorEscapeTime = 1200; // 20 Minutos para resgate dos humanos
    level.elapsedGameTime = 0;
    level.zombiesReleased = false;
    level.survivorBonus = 75;

    level thread setupDamageCallback();
    level thread onPlayerConnect();
    level thread matchLifecycleWatcher();
    level thread survivorTimerWatcher();
    level thread passiveIncomeLoop();
}

// =========================================================================
// SISTEMA REAL DE DANO (BYPASS DIRETO DE FRIENDLY-FIRE / MELEE LOCK)
// =========================================================================

setupDamageCallback()
{
    while(!isDefined(level.callbackPlayerDamage))
        wait 0.05;

    level.original_callbackPlayerDamage = level.callbackPlayerDamage;
    level.callbackPlayerDamage = ::customCallbackPlayerDamage;
}

customCallbackPlayerDamage(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, timeOffset)
{
    // Ataque entre jogadores
    if(isDefined(eAttacker) && isPlayer(eAttacker) && eAttacker != self)
    {
        // 1. Mesmo grupo (Humano x Humano ou Zumbi x Zumbi): bloqueio total sem hitmarker
        if(self.status == eAttacker.status)
            return;

        // 2. Alvo em God Mode
        if(isDefined(self.isInvulnerable) && self.isInvulnerable)
            return;

        // 3. Cálculo de dano real garantido
        dmg = iDamage;
        if(sMeansOfDeath == "MOD_MELEE" || isSubStr(sWeapon, "knife"))
        {
            dmg = 115; // 1 Hit kill em 100 HP, 2 Hits se tiver Juggernog
        }

        // Bônus financeiro por acerto
        if(self.status == "zombie" && eAttacker.status == "human")
            eAttacker.money += 20;
        else if(self.status == "human" && eAttacker.status == "zombie")
            eAttacker.money += 25;

        // Som de confirmação de acerto no atacante
        eAttacker playLocalSound("mp_hit_alert");

        // Aplicação física de dano direta
        self.health -= dmg;

        // 4. Verificação de morte
        if(self.health <= 0)
        {
            if(self.status == "zombie" && eAttacker.status == "human")
            {
                eAttacker.money += 150;
                eAttacker iPrintln("^2+$150 ^7Zombie Eliminated!");
            }
            else if(self.status == "human" && eAttacker.status == "zombie")
            {
                eAttacker.money += 200;
                eAttacker iPrintln("^1+$200 ^7Survivor Infected!");
            }

            self.health = 1;
            self thread killPlayerCleanly(eAttacker, sWeapon, sMeansOfDeath);
        }
        return;
    }

    // Dano ambiental (quedas, explosões próprias)
    if(isDefined(self.isInvulnerable) && self.isInvulnerable && sMeansOfDeath != "MOD_SUICIDE")
        return;

    self [[level.original_callbackPlayerDamage]](eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, timeOffset);
}

killPlayerCleanly(attacker, weapon, meansOfDeath)
{
    self endon("disconnect");
    wait 0.05;
    if(isAlive(self))
    {
        if(isDefined(attacker) && isPlayer(attacker))
            obituary(self, attacker, weapon, meansOfDeath);
        self suicide();
    }
}

// =========================================================================
// CICLO DE VIDA DO JOGADOR
// =========================================================================

onPlayerConnect()
{
    for(;;)
    {
        level waittill("connected", player);

        player.status = "human";
        player.money = 250;
        player.usingZipline = false;
        player.quickShopOpen = false;
        player.fullMenuOpen = false;
        player.menuState = "CATEGORIES";
        player.currentCategory = 0;
        player.menuCursor = 0;

        player thread onPlayerSpawned();
        player thread onPlayerDied();
        player thread onPlayerDisconnect();
    }
}

onPlayerSpawned()
{
    self endon("disconnect");
    for(;;)
    {
        self waittill("spawned_player");

        if(!isDefined(level.customMapSpawned))
        {
            level.customMapSpawned = true;
            level thread maps\mp\_ambientpackage::setupCustomMap();
            iPrintlnBold("^2Welcome to ZPGDK ZombieLand - Beta !");
        }

        if(self.status == "zombie")
        {
            self setModel("c_usa_mp_seal6_sniper_fb");
            self takeAllWeapons();
            self giveWeapon("knife_mp");
            self switchToWeapon("knife_mp");
            self setMoveSpeedScale(1.15);
            self thread zombieWeaponLock();
        }
        else
        {
            self setModel("c_usa_mp_seal6_lmg_fb");
            self setMoveSpeedScale(1.0);
        }

        self thread setupPlayerHUD();
        self thread setupMenuHUD();
        self thread controlsWatcher();
        self iPrintln("^2Welcome to ZPGDK ZombieLand - Beta !");
    }
}

// Remove armas de fogo recolhidas do chão por zumbis
zombieWeaponLock()
{
    self endon("disconnect");
    self endon("death");

    for(;;)
    {
        wait 0.2;
        if(self.status == "zombie")
        {
            weapons = self getWeaponsListPrimaries();
            foreach(w in weapons)
            {
                if(w != "knife_mp" && w != "knife_ballistic_mp" && w != "hatchet_mp")
                {
                    self takeWeapon(w);
                    self switchToWeapon("knife_mp");
                    self iPrintlnBold("^1Zombies cannot use firearms!");
                }
            }
        }
    }
}

onPlayerDied()
{
    self endon("disconnect");
    for(;;)
    {
        self waittill("death");

        if(self.fullMenuOpen)
            self closeFullMenu();

        if(!level.zombiesReleased)
            continue;

        if(self.status == "human")
        {
            self.status = "zombie";
            iPrintlnBold(self.name + " ^1was INFECTED!");

            foreach(p in level.players)
            {
                if(isDefined(p) && p.status == "human")
                {
                    p.money += level.survivorBonus;
                    p iPrintln("^2+$" + level.survivorBonus + " ^7Infection Survivor Bonus!");
                }
            }
        }
    }
}

onPlayerDisconnect()
{
    self waittill("disconnect");
    if(isDefined(self.moneyHud)) self.moneyHud destroy();
    if(isDefined(self.healthHud)) self.healthHud destroy();
    if(isDefined(self.menu_title)) self.menu_title destroy();
    if(isDefined(self.menu_footer)) self.menu_footer destroy();
    if(isDefined(self.menu_options))
    {
        for(i = 0; i < self.menu_options.size; i++)
            self.menu_options[i] destroy();
    }
}

passiveIncomeLoop()
{
    level endon("game_ended");

    for(;;)
    {
        wait 12.0;
        foreach(p in level.players)
        {
            if(!isAlive(p)) continue;

            if(p.status == "human")
            {
                p.money += 45;
                p iPrintln("^2+$45 ^7Survivor Survival Bonus");
            }
            else if(p.status == "zombie")
            {
                p.money += 35;
                p iPrintln("^1+$35 ^7Infection Stalker Bonus");
            }
        }
    }
}

// =========================================================================
// CONTROLE DE PARTIDA
// =========================================================================

matchLifecycleWatcher()
{
    level endon("game_ended");

    while(level.zombieficationTime > 0)
    {
        iPrintlnBold("^1Infection begins in: " + level.zombieficationTime + "s");
        wait 5;
        level.zombieficationTime -= 5;
    }

    candidates = [];
    foreach(p in level.players)
    {
        if(isAlive(p) && !p isHost())
            candidates[candidates.size] = p;
    }

    if(candidates.size == 0 && level.players.size > 0)
        candidates = level.players;

    if(candidates.size > 0)
    {
        firstZombie = candidates[randomInt(candidates.size)];
        firstZombie.status = "zombie";
        firstZombie suicide();
        iPrintlnBold("^1" + firstZombie.name + " is Patient Zero!");
    }

    level.zombiesReleased = true;

    for(;;)
    {
        wait 1.0;
        humans = 0;

        foreach(p in level.players)
        {
            if(p.status == "human") humans++;
        }

        if(level.zombiesReleased && humans == 0 && level.players.size > 1)
        {
            level thread concludeGame("axis", "^1ALL HUMANS INFECTED! ZOMBIES WIN!");
            break;
        }
    }
}

survivorTimerWatcher()
{
    level endon("game_ended");

    while(level.elapsedGameTime < level.survivorEscapeTime)
    {
        wait 1.0;
        level.elapsedGameTime++;
    }
    level thread concludeGame("allies", "^2SURVIVORS RESCUED! HUMANS WIN!");
}

concludeGame(winner, text)
{
    if(level.gameEnded) return;
    level.gameEnded = true;
    iPrintlnBold(text);
    wait 2.0;
    maps\mp\gametypes\_globallogic::endGame(winner, text);
}

// =========================================================================
// HUD SYSTEM
// =========================================================================

setupPlayerHUD()
{
    self endon("disconnect");

    if(isDefined(self.hudActive)) return;
    self.hudActive = true;

    self.moneyHud = createFontString("objective", 1.4);
    self.moneyHud setPoint("TOP LEFT", "TOP LEFT", 12, 12);
    self.moneyHud.label = &"Cash: $";
    self.moneyHud.color = (0.2, 1, 0.2);
    self.moneyHud.alpha = 1;

    self.healthHud = createFontString("objective", 1.4);
    self.healthHud setPoint("TOP LEFT", "TOP LEFT", 12, 32);
    self.healthHud.label = &"Health: ";
    self.healthHud.color = (1, 0.2, 0.2);
    self.healthHud.alpha = 1;

    for(;;)
    {
        wait 0.1;
        if(!isDefined(self)) break;

        self.moneyHud setValue(self.money);
        self.healthHud setValue(self.health);
    }
}

setupMenuHUD()
{
    self endon("disconnect");

    if(isDefined(self.menuHudActive)) return;
    self.menuHudActive = true;

    // Título sem background
    self.menu_title = createFontString("objective", 1.35);
    self.menu_title setPoint("TOP LEFT", "TOP LEFT", 28, 88);
    self.menu_title.color = (1, 0.85, 0.2);
    self.menu_title.glowAlpha = 1.0;
    self.menu_title.glowColor = (0, 0, 0);
    self.menu_title.alpha = 0;

    self.menu_options = [];
    for(i = 0; i < 7; i++)
    {
        opt = createFontString("objective", 1.2);
        opt setPoint("TOP LEFT", "TOP LEFT", 32, 115 + (i * 21));
        opt.glowAlpha = 1.0;
        opt.glowColor = (0, 0, 0);
        opt.alpha = 0;
        self.menu_options[i] = opt;
    }

    self.menu_footer = createFontString("objective", 0.95);
    self.menu_footer setPoint("TOP LEFT", "TOP LEFT", 28, 275);
    self.menu_footer setText("[{+actionslot 1}]/[{+actionslot 2}]: Scroll  [{+activate}]: Select  [{+melee}]: Back");
    self.menu_footer.color = (0.8, 0.8, 0.8);
    self.menu_footer.glowAlpha = 1.0;
    self.menu_footer.glowColor = (0, 0, 0);
    self.menu_footer.alpha = 0;
}

// =========================================================================
// LOJA & NAVEGAÇÃO
// =========================================================================

controlsWatcher()
{
    self endon("disconnect");

    for(;;)
    {
        wait 0.05;

        // DPAD UP: Quick Shop (fora do menu) ou Scroll Up (dentro do menu)
        if(self actionSlotOneButtonPressed())
        {
            if(!self.fullMenuOpen)
            {
                self.quickShopOpen = !self.quickShopOpen;
                if(self.quickShopOpen)
                {
                    self iPrintlnBold("^3--- QUICK SHOP ---");
                    if(self.status == "human")
                        self iPrintln("^7Press [{+activate}] to Quick-Buy: ^2Emergency Ammo ($200)");
                    else
                        self iPrintln("^7Press [{+activate}] to Quick-Buy: ^2Feral Speed ($250)");
                }
                else
                    self iPrintlnBold("^1Quick Shop Closed");
                wait 0.25;
            }
            else
            {
                total = self getCurrentOptionsList().size;
                self.menuCursor = (self.menuCursor - 1 + total) % total;
                self renderMenu();
                wait 0.16;
            }
        }

        // DPAD DOWN: Abre o Menu Completo ou Scroll Down
        if(self actionSlotTwoButtonPressed())
        {
            if(!self.fullMenuOpen)
            {
                self openFullMenu();
            }
            else
            {
                total = self getCurrentOptionsList().size;
                self.menuCursor = (self.menuCursor + 1) % total;
                self renderMenu();
            }
            wait 0.16;
        }

        // BOTÃO USE / ATIVAR: Seleciona categoria ou adquire item
        if(self useButtonPressed())
        {
            if(self.fullMenuOpen)
            {
                self onMenuSelect();
                wait 0.25;
            }
            else if(self.quickShopOpen)
            {
                self handleQuickBuy();
                wait 0.3;
            }
        }

        // BOTÃO MELEE: Voltar para Categorias ou Fechar Menu
        if(self meleeButtonPressed() && self.fullMenuOpen)
        {
            if(self.menuState == "SUBMENU")
            {
                self.menuState = "CATEGORIES";
                self.menuCursor = self.currentCategory;
                self renderMenu();
            }
            else
            {
                self closeFullMenu();
            }
            wait 0.25;
        }
    }
}

handleQuickBuy()
{
    if(self.status == "human")
    {
        if(self.money >= 200)
        {
            self.money -= 200;
            w = self getCurrentWeapon();
            self giveMaxAmmo(w);
            self iPrintlnBold("^2Ammo Refilled! (-$200)");
        }
        else self iPrintlnBold("^1Need $200 for Quick Ammo!");
    }
    else
    {
        if(self.money >= 250)
        {
            self.money -= 250;
            self setMoveSpeedScale(1.4);
            self iPrintlnBold("^2Feral Speed Boost Applied! (-$250)");
        }
        else self iPrintlnBold("^1Need $250 for Speed!");
    }
}

getCategories()
{
    return array("Weapons Depot", "Perks & Powers", "Bunkers & Buildables", "Out-Of-Map & Specials");
}

getCurrentOptionsList()
{
    if(self.menuState == "CATEGORIES")
        return self getCategories();

    cat = self.currentCategory;
    if(self.status == "human")
    {
        switch(cat)
        {
            case 0:
                return array("AN-94 Assault ($800)", "DSR-50 Sniper ($900)", "Minigun Super Weapon ($2500)", "Refill All Ammo ($200)");
            case 1:
                return array("Juggernog (+200 Health) ($500)", "Speed Cola (Fast Reload) ($300)", "Stamin-Up (Unlimited Sprint) ($300)", "Fast Hands (Fast Swap) ($200)");
            case 2:
                return array("Deploy Personal Bunker ($1500)", "Spawn Mystery Box ($800)", "Sentry Gun Killstreak ($1200)");
            case 3:
                return array("Open Out-Of-Bounds Teleport ($1500)", "15s Godmode Invulnerability ($2000)");
        }
    }
    else
    {
        switch(cat)
        {
            case 0:
                return array("Ballistic Knife ($500)", "Combat Tomahawk x2 ($150)");
            case 1:
                return array("+250 Zombie Health ($350)", "Super Speed Multiplier ($350)");
            case 2:
                return array("Spawn Mystery Box for Humans ($600)");
            case 3:
                return array("Open Out-Of-Bounds Teleport ($1000)", "10s Cloak Invisibility ($700)", "Kamikaze C4 Explosion ($900)");
        }
    }
    return [];
}

openFullMenu()
{
    self.fullMenuOpen = true;
    self.quickShopOpen = false;
    self.menuState = "CATEGORIES";
    self.menuCursor = 0;

    self.menu_title.alpha = 1;
    self.menu_footer.alpha = 1;

    self renderMenu();
}

closeFullMenu()
{
    self.fullMenuOpen = false;
    self.menu_title.alpha = 0;
    self.menu_footer.alpha = 0;

    for(i = 0; i < self.menu_options.size; i++)
        self.menu_options[i].alpha = 0;
}

renderMenu()
{
    if(self.menuState == "CATEGORIES")
    {
        self.menu_title setText(self.status == "human" ? "SHOP: SELECT CATEGORY" : "MUTATION: SELECT CATEGORY");
    }
    else
    {
        cats = self getCategories();
        self.menu_title setText(cats[self.currentCategory]);
    }

    opts = self getCurrentOptionsList();

    for(i = 0; i < self.menu_options.size; i++)
    {
        if(i < opts.size)
        {
            if(i == self.menuCursor)
            {
                self.menu_options[i] setText("^2> ^7" + opts[i]);
                self.menu_options[i].color = (1, 1, 1);
            }
            else
            {
                self.menu_options[i] setText("  ^7" + opts[i]);
                self.menu_options[i].color = (0.7, 0.7, 0.7);
            }
            self.menu_options[i].alpha = 1;
        }
        else
        {
            self.menu_options[i].alpha = 0;
        }
    }
}

onMenuSelect()
{
    if(self.menuState == "CATEGORIES")
    {
        self.currentCategory = self.menuCursor;
        self.menuState = "SUBMENU";
        self.menuCursor = 0;
        self renderMenu();
        return;
    }

    cat = self.currentCategory;
    idx = self.menuCursor;

    if(self.status == "human")
    {
        if(cat == 0) // Weapons
        {
            if(idx == 0 && self verifyCash(800))
            {
                self giveWeapon("an94_mp");
                self switchToWeapon("an94_mp");
                self giveMaxAmmo("an94_mp");
            }
            else if(idx == 1 && self verifyCash(900))
            {
                self giveWeapon("dsr50_mp");
                self switchToWeapon("dsr50_mp");
                self giveMaxAmmo("dsr50_mp");
            }
            else if(idx == 2 && self verifyCash(2500))
            {
                self giveWeapon("minigun_wager_mp");
                self switchToWeapon("minigun_wager_mp");
                self giveMaxAmmo("minigun_wager_mp");
            }
            else if(idx == 3 && self verifyCash(200))
            {
                w = self getCurrentWeapon();
                self giveMaxAmmo(w);
            }
        }
        else if(cat == 1) // Perks
        {
            if(idx == 0 && self verifyCash(500))
            {
                self.maxhealth += 200;
                self.health = self.maxhealth;
                self setPerk("specialty_extraammo");
                self iPrintlnBold("^2Juggernog Applied (+200 HP)!");
            }
            else if(idx == 1 && self verifyCash(300))
            {
                self setPerk("specialty_fastreload");
                self iPrintlnBold("^2Speed Cola Granted!");
            }
            else if(idx == 2 && self verifyCash(300))
            {
                self setPerk("specialty_unlimitedsprint");
                self iPrintlnBold("^2Stamin-Up Granted!");
            }
            else if(idx == 3 && self verifyCash(200))
            {
                self setPerk("specialty_fastweaponswitch");
                self setPerk("specialty_fastmantle");
                self iPrintlnBold("^2Fast Hands & Mantle Granted!");
            }
        }
        else if(cat == 2) // Buildables
        {
            if(idx == 0 && self verifyCash(1500))
                maps\mp\_ambientpackage::spawnBunkerAtPlayer(self);
            else if(idx == 1 && self verifyCash(800))
                maps\mp\_ambientpackage::createMysteryBox(self.origin + vectorScale(anglesToForward(self.angles), 50), self.angles, 150);
            else if(idx == 2 && self verifyCash(1200))
            {
                // Concede Sentry Gun Killstreak nativo (Zero crashes)
                self maps\mp\killstreaks\_killstreaks::givekillstreak("autoturret");
                self iPrintlnBold("^2Sentry Gun Killstreak Ready! Press [{+actionslot 4}] to place.");
            }
        }
        else if(cat == 3) // Specials
        {
            if(idx == 0 && self verifyCash(1500))
                maps\mp\_ambientpackage::spawnOutOfMapTeleport(self);
            else if(idx == 1 && self verifyCash(2000))
                self thread triggerInvulnerability(15);
        }
    }
    else // Zombie Purchases
    {
        if(cat == 0) // Weapons
        {
            if(idx == 0 && self verifyCash(500))
            {
                self giveWeapon("knife_ballistic_mp");
                self switchToWeapon("knife_ballistic_mp");
            }
            else if(idx == 1 && self verifyCash(150))
            {
                self giveWeapon("hatchet_mp");
                self setWeaponAmmoClip("hatchet_mp", 2);
            }
        }
        else if(cat == 1) // Powers
        {
            if(idx == 0 && self verifyCash(350))
            {
                self.maxhealth += 250;
                self.health = self.maxhealth;
            }
            else if(idx == 1 && self verifyCash(350))
            {
                self setMoveSpeedScale(1.45);
            }
        }
        else if(cat == 2) // Buildables
        {
            if(idx == 0 && self verifyCash(600))
                maps\mp\_ambientpackage::createMysteryBox(self.origin + vectorScale(anglesToForward(self.angles), 50), self.angles, 150);
        }
        else if(cat == 3) // Specials
        {
            if(idx == 0 && self verifyCash(1000))
                maps\mp\_ambientpackage::spawnOutOfMapTeleport(self);
            else if(idx == 1 && self verifyCash(700))
                self thread triggerInvisibility(10);
            else if(idx == 2 && self verifyCash(900))
                self thread triggerKamikaze();
        }
    }
}

verifyCash(cost)
{
    if(self.money >= cost)
    {
        self.money -= cost;
        self iPrintlnBold("^2Purchased! (-$" + cost + ")");
        return true;
    }
    self iPrintlnBold("^1Insufficient Cash! ($" + cost + " required)");
    return false;
}

triggerInvulnerability(duration)
{
    self endon("disconnect");
    self.isInvulnerable = true;
    self iPrintlnBold("^3GODMODE ACTIVE FOR " + duration + "s!");
    wait duration;
    self.isInvulnerable = false;
    self iPrintlnBold("^1Godmode Expired!");
}

triggerInvisibility(duration)
{
    self endon("disconnect");
    self hide();
    self iPrintlnBold("^3INVISIBILITY ACTIVE FOR " + duration + "s!");
    wait duration;
    self show();
    self iPrintlnBold("^1Invisibility Expired!");
}

triggerKamikaze()
{
    self endon("disconnect");
    self iPrintlnBold("^1SUICIDE CHARGE PRIMED! Exploding in 3s!");
    wait 3.0;
    if(isAlive(self))
    {
        radiusDamage(self.origin, 320, 500, 200, self, "MOD_EXPLOSIVE", "satchel_charge_mp");
        playFx("explosions/fx_default_explosion", self.origin);
        self suicide();
    }
}