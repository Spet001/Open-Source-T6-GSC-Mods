#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes\_hud_util;
#include maps\mp\gametypes\_hud_message;

init()
{
    // Habilita killstreaks na partida
    level.loadoutKillstreaksEnabled = true;

    // Precache de Armas Primárias e Pistolas
    precacheItem("knife_mp");
    precacheItem("fiveseven_mp");
    precacheItem("beretta93r_mp");
    precacheItem("judge_mp");
    precacheItem("kard_mp");
    precacheItem("fnp45_mp");

    precacheItem("mp7_mp");
    precacheItem("pdw57_mp");
    precacheItem("insas_mp");
    precacheItem("vector_mp");
    precacheItem("870mcs_mp");
    precacheItem("ksg_mp");

    precacheItem("hk416_mp");
    precacheItem("an94_mp");
    precacheItem("scar_mp");
    precacheItem("sa58_mp");
    precacheItem("dsr50_mp");
    precacheItem("ballista_mp");

    // Precache de Armas com Attachments
    precacheItem("an94_mp+silencer+reflex");
    precacheItem("an94_mp+fmj+dualclip");
    precacheItem("hk416_mp+silencer+acog");
    precacheItem("scar_mp+reflex+grip");
    precacheItem("insas_mp+rf+dualclip");
    precacheItem("mp7_mp+silencer+laser");
    precacheItem("dsr50_mp+ballistics+dualclip");
    precacheItem("ballista_mp+is");
    precacheItem("870mcs_mp+extbarrel+laser");

    // Precache de Specials & Heavy Weapons
    precacheItem("riotshield_mp");
    precacheItem("crossbow_mp");
    precacheItem("m32_wager_mp");
    precacheItem("minigun_wager_mp");
    precacheItem("knife_ballistic_mp");

    // Precache de Granadas
    precacheItem("frag_grenade_mp");
    precacheItem("concussion_grenade_mp");
    precacheItem("willy_pete_mp");

    level.csMaxMoney = 16000;
    level.csKillReward = 300;
    level.csRoundWin = 3250;
    level.csRoundLoss = 1400;

    level thread setupDamageCallback();
    level thread onPlayerConnect();
    level thread roundMonitor();
    level thread passiveIncomeTimer();
}

// =========================================================================
// SISTEMA DE DANO REAL & HITMARKERS NATIVOS
// =========================================================================

setupDamageCallback()
{
    while(!isDefined(level.callbackPlayerDamage))
        wait 0.05;

    level.original_callbackPlayerDamage = level.callbackPlayerDamage;
    level.callbackPlayerDamage = ::customCallbackPlayerDamage;
}

customCallbackPlayerDamage(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, timeOffset, boneIndex)
{
    finalDamage = iDamage;

    // Absorção pelo Colete Kevlar (50% do dano absorvido)
    if(isDefined(self.armor) && self.armor > 0 && sMeansOfDeath != "MOD_FALLING" && sMeansOfDeath != "MOD_SUICIDE")
    {
        absorbed = int(finalDamage * 0.5);
        if(self.armor >= absorbed)
        {
            self.armor -= absorbed;
            finalDamage = finalDamage - absorbed;
        }
        else
        {
            finalDamage = finalDamage - self.armor;
            self.armor = 0;
            self iPrintlnBold("^1Armor Broken!");
        }
    }

    // Combate entre jogadores
    if(isDefined(eAttacker) && isPlayer(eAttacker) && eAttacker != self)
    {
        if(level.teamBased && self.team == eAttacker.team && !level.friendlyfire)
            return;

        eAttacker thread maps\mp\gametypes\_damagefeedback::updateDamageFeedback(sMeansOfDeath);
        eAttacker playLocalSound("mp_hit_alert");

        self.health -= finalDamage;

        if(self.health <= 0)
        {
            eAttacker.money = min(eAttacker.money + level.csKillReward, level.csMaxMoney);
            eAttacker iPrintln("^2+$" + level.csKillReward + " ^7Kill Award!");

            self.health = 1;
            self thread killPlayerCleanly(eAttacker, sWeapon, sMeansOfDeath);
        }
        return;
    }

    self [[level.original_callbackPlayerDamage]](eInflictor, eAttacker, finalDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, timeOffset);
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

        if(!isDefined(player.money))
            player.money = 800;

        player.armor = 0;
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

        // PISTOL ROUND: Confisca armas e equipa Five-Seven + Faca
        self takeAllWeapons();
        self giveWeapon("knife_mp");
        self giveWeapon("fiveseven_mp");
        self giveMaxAmmo("fiveseven_mp");
        self switchToWeapon("fiveseven_mp");

        if(!isDefined(self.armor))
            self.armor = 0;

        self thread setupHUDs();

        // Encerra threads duplicadas de controle
        self notify("stop_controls_watcher");
        self thread controlsWatcher();

        self iPrintlnBold("^2CS Mode Active! Press [{+actionslot 2}] to Open Buy Menu.");
    }
}

onPlayerDied()
{
    self endon("disconnect");
    for(;;)
    {
        self waittill("death");
        self closeFullMenu();
    }
}

onPlayerDisconnect()
{
    self waittill("disconnect");
    if(isDefined(self.hud_money)) self.hud_money destroy();
    if(isDefined(self.hud_health)) self.hud_health destroy();
    if(isDefined(self.hud_armor)) self.hud_armor destroy();
    if(isDefined(self.menu_title)) self.menu_title destroy();
    if(isDefined(self.menu_footer)) self.menu_footer destroy();
    if(isDefined(self.menu_options))
    {
        for(i = 0; i < self.menu_options.size; i++)
            self.menu_options[i] destroy();
    }
}

roundMonitor()
{
    level endon("game_ended");

    for(;;)
    {
        level waittill_any("round_end", "round_ended");
        wait 0.5;

        winner = game["winner"];
        foreach(player in level.players)
        {
            if(!isDefined(player.money))
                player.money = 800;

            if(isDefined(winner) && player.team == winner)
            {
                player.money = min(player.money + level.csRoundWin, level.csMaxMoney);
                player iPrintlnBold("^2+$" + level.csRoundWin + " ^7Round Won Bonus!");
            }
            else
            {
                player.money = min(player.money + level.csRoundLoss, level.csMaxMoney);
                player iPrintlnBold("^1+$" + level.csRoundLoss + " ^7Round Loss Compensation!");
            }
        }
    }
}

passiveIncomeTimer()
{
    level endon("game_ended");

    for(;;)
    {
        wait 30.0;
        foreach(player in level.players)
        {
            if(isAlive(player))
            {
                player.money = min(player.money + 150, level.csMaxMoney);
                player iPrintln("^2+$150 ^7Round Stasis Award");
            }
        }
    }
}

// =========================================================================
// HUD SYSTEM (REPOSICIONADO PARA NÃO CLIPAR)
// =========================================================================

setupHUDs()
{
    self endon("disconnect");

    if(isDefined(self.csHUDActive)) return;
    self.csHUDActive = true;

    self.hud_money = createFontString("objective", 1.4);
    self.hud_money setPoint("TOP LEFT", "TOP LEFT", 12, 12);
    self.hud_money.label = &"Cash: $";
    self.hud_money.color = (0.2, 1, 0.2);
    self.hud_money.glowAlpha = 1.0;
    self.hud_money.glowColor = (0, 0, 0);

    self.hud_health = createFontString("objective", 1.3);
    self.hud_health setPoint("TOP LEFT", "TOP LEFT", 12, 30);
    self.hud_health.label = &"HP: ";
    self.hud_health.color = (1, 0.2, 0.2);
    self.hud_health.glowAlpha = 1.0;
    self.hud_health.glowColor = (0, 0, 0);

    self.hud_armor = createFontString("objective", 1.3);
    self.hud_armor setPoint("TOP LEFT", "TOP LEFT", 12, 48);
    self.hud_armor.label = &"Armor: ";
    self.hud_armor.color = (0.3, 0.7, 1);
    self.hud_armor.glowAlpha = 1.0;
    self.hud_armor.glowColor = (0, 0, 0);

    // Título mais alto (Y = 55)
    self.menu_title = createFontString("objective", 1.3);
    self.menu_title setPoint("TOP LEFT", "TOP LEFT", 28, 55);
    self.menu_title.color = (1, 0.85, 0.2);
    self.menu_title.glowAlpha = 1.0;
    self.menu_title.glowColor = (0, 0, 0);
    self.menu_title.alpha = 0;

    // Espaçamento de 18px entre opções
    self.menu_options = [];
    for(i = 0; i < 10; i++)
    {
        opt = createFontString("objective", 1.1);
        opt setPoint("TOP LEFT", "TOP LEFT", 32, 78 + (i * 18));
        opt.glowAlpha = 1.0;
        opt.glowColor = (0, 0, 0);
        opt.alpha = 0;
        self.menu_options[i] = opt;
    }

    self.menu_footer = createFontString("objective", 0.9);
    self.menu_footer setPoint("TOP LEFT", "TOP LEFT", 28, 262);
    self.menu_footer setText("[{+actionslot 1}]/[{+actionslot 2}]: Scroll  [{+activate}]: Buy  [{+melee}]: Back");
    self.menu_footer.color = (0.8, 0.8, 0.8);
    self.menu_footer.glowAlpha = 1.0;
    self.menu_footer.glowColor = (0, 0, 0);
    self.menu_footer.alpha = 0;

    for(;;)
    {
        wait 0.1;
        if(!isDefined(self)) break;

        self.hud_money setValue(self.money);
        self.hud_health setValue(self.health);
        self.hud_armor setValue(self.armor);
    }
}

// =========================================================================
// CONTROLES E NAVEGAÇÃO DO BUY MENU
// =========================================================================

controlsWatcher()
{
    self endon("disconnect");
    self endon("stop_controls_watcher");

    for(;;)
    {
        wait 0.05;

        // DPAD DOWN: Alterna abertura ou Scroll Down
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

        // DPAD UP: Scroll Up
        if(self actionSlotOneButtonPressed() && self.fullMenuOpen)
        {
            total = self getCurrentOptionsList().size;
            self.menuCursor = (self.menuCursor - 1 + total) % total;
            self renderMenu();
            wait 0.16;
        }

        // USE (F / X): Comprar
        if(self useButtonPressed() && self.fullMenuOpen)
        {
            self onMenuSelect();
            wait 0.25;
        }

        // MELEE (V / RS): Voltar às categorias ou Fechar
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

getCategories()
{
    return array("Pistols", "SMGs & Shotguns", "Rifles & Snipers", "Tactical (Attachments)", "Heavy & Specials", "Gear & Armor", "Grenades", "Killstreaks");
}

getCurrentOptionsList()
{
    if(self.menuState == "CATEGORIES")
        return self getCategories();

    cat = self.currentCategory;
    switch(cat)
    {
        case 0: // Pistols
            return array("Five-Seven ($300)", "Tac-45 ($350)", "B23R Burst ($400)", "Executioner Deagle ($650)", "KAP-40 Auto ($800)");
        case 1: // SMGs & Shotguns
            return array("MP7 ($1200)", "Vector K10 ($1400)", "PDW-57 ($1500)", "MSMC ($1700)", "Remington 870 ($1200)", "KSG Shotgun ($1500)");
        case 2: // Rifles & Snipers
            return array("M27 Carbine ($2700)", "FAL OSW Semi ($2900)", "AN-94 Assault ($3100)", "SCAR-H Heavy ($3500)", "Ballista Sniper ($4200)", "DSR-50 AWP ($4750)");
        case 3: // Tactical (Attachments)
            return array("AN-94 + Silencer & Reflex ($3600)", "AN-94 + FMJ & Fast Mag ($3700)", "M27 + Suppressor & ACOG ($3400)", "SCAR-H + Reflex & Foregrip ($3900)", "MSMC + Rapid Fire & Fast Mag ($2300)", "MP7 + Silencer & Laser ($1800)", "DSR-50 + Ballistics & Fast Mag ($5400)", "Ballista + Iron Sights ($4500)", "Remington + Long Barrel & Laser ($1700)");
        case 4: // Heavy & Specials
            return array("Riot Shield ($1500)", "Tactical Crossbow ($2000)", "War Machine M32 ($3500)", "Death Machine Minigun ($4500)", "Ballistic Knife ($1000)");
        case 5: // Gear & Armor
            return array("Kevlar Body Armor ($650)", "Kevlar + Heavy Helmet ($1000)", "Fast Hands & Fast Reload ($400)", "Lightweight & Stamin-Up ($500)");
        case 6: // Grenades
            return array("Frag Grenade HE ($300)", "Concussion Flash ($200)", "Smoke Grenade ($300)");
        case 7: // Killstreaks
            return array("UAV Recon Radar ($1500)", "RC-XD Bomb Car ($2000)", "Sentry Gun ($3000)");
    }
    return [];
}

openFullMenu()
{
    self.fullMenuOpen = true;
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
        self.menu_title setText("CS BUY MENU: CATEGORIES");
    }
    else
    {
        cats = self getCategories();
        self.menu_title setText("BUY MENU: " + cats[self.currentCategory]);
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

    // 0: PISTOLS
    if(cat == 0)
    {
        if(idx == 0 && self verifyCash(300))
            self switchSidearm("fiveseven_mp");
        else if(idx == 1 && self verifyCash(350))
            self switchSidearm("fnp45_mp");
        else if(idx == 2 && self verifyCash(400))
            self switchSidearm("beretta93r_mp");
        else if(idx == 3 && self verifyCash(650))
            self switchSidearm("judge_mp");
        else if(idx == 4 && self verifyCash(800))
            self switchSidearm("kard_mp");
    }
    // 1: SMGs & SHOTGUNS
    else if(cat == 1)
    {
        if(idx == 0 && self verifyCash(1200))
            self equipPrimary("mp7_mp");
        else if(idx == 1 && self verifyCash(1400))
            self equipPrimary("vector_mp");
        else if(idx == 2 && self verifyCash(1500))
            self equipPrimary("pdw57_mp");
        else if(idx == 3 && self verifyCash(1700))
            self equipPrimary("insas_mp");
        else if(idx == 4 && self verifyCash(1200))
            self equipPrimary("870mcs_mp");
        else if(idx == 5 && self verifyCash(1500))
            self equipPrimary("ksg_mp");
    }
    // 2: RIFLES & SNIPERS
    else if(cat == 2)
    {
        if(idx == 0 && self verifyCash(2700))
            self equipPrimary("hk416_mp");
        else if(idx == 1 && self verifyCash(2900))
            self equipPrimary("sa58_mp");
        else if(idx == 2 && self verifyCash(3100))
            self equipPrimary("an94_mp");
        else if(idx == 3 && self verifyCash(3500))
            self equipPrimary("scar_mp");
        else if(idx == 4 && self verifyCash(4200))
            self equipPrimary("ballista_mp");
        else if(idx == 5 && self verifyCash(4750))
            self equipPrimary("dsr50_mp");
    }
    // 3: TACTICAL (ATTACHMENTS)
    else if(cat == 3)
    {
        if(idx == 0 && self verifyCash(3600))
            maps\mp\_ambientpackage::giveWeaponWithAttachments("an94_mp", "silencer", "reflex");
        else if(idx == 1 && self verifyCash(3700))
            maps\mp\_ambientpackage::giveWeaponWithAttachments("an94_mp", "fmj", "dualclip");
        else if(idx == 2 && self verifyCash(3400))
            maps\mp\_ambientpackage::giveWeaponWithAttachments("hk416_mp", "silencer", "acog");
        else if(idx == 3 && self verifyCash(3900))
            maps\mp\_ambientpackage::giveWeaponWithAttachments("scar_mp", "reflex", "grip");
        else if(idx == 4 && self verifyCash(2300))
            maps\mp\_ambientpackage::giveWeaponWithAttachments("insas_mp", "rf", "dualclip");
        else if(idx == 5 && self verifyCash(1800))
            maps\mp\_ambientpackage::giveWeaponWithAttachments("mp7_mp", "silencer", "laser");
        else if(idx == 6 && self verifyCash(5400))
            maps\mp\_ambientpackage::giveWeaponWithAttachments("dsr50_mp", "ballistics", "dualclip");
        else if(idx == 7 && self verifyCash(4500))
            maps\mp\_ambientpackage::giveWeaponWithAttachments("ballista_mp", "is", "");
        else if(idx == 8 && self verifyCash(1700))
            maps\mp\_ambientpackage::giveWeaponWithAttachments("870mcs_mp", "extbarrel", "laser");
    }
    // 4: HEAVY & SPECIALS
    else if(cat == 4)
    {
        if(idx == 0 && self verifyCash(1500))
            self equipPrimary("riotshield_mp");
        else if(idx == 1 && self verifyCash(2000))
            self equipPrimary("crossbow_mp");
        else if(idx == 2 && self verifyCash(3500))
            self equipPrimary("m32_wager_mp");
        else if(idx == 3 && self verifyCash(4500))
            self equipPrimary("minigun_wager_mp");
        else if(idx == 4 && self verifyCash(1000))
            self equipPrimary("knife_ballistic_mp");
    }
    // 5: GEAR & ARMOR
    else if(cat == 5)
    {
        if(idx == 0 && self verifyCash(650))
        {
            self.armor = 100;
            self iPrintlnBold("^2Kevlar Vest Equipped (+100 Armor)!");
        }
        else if(idx == 1 && self verifyCash(1000))
        {
            self.armor = 100;
            self.maxhealth = 200;
            self.health = 200;
            self iPrintlnBold("^2Kevlar + Heavy Helmet (+100 Armor & +100 HP)!");
        }
        else if(idx == 2 && self verifyCash(400))
        {
            self setPerk("specialty_fastweaponswitch");
            self setPerk("specialty_fastreload");
            self iPrintlnBold("^2Fast Hands & Fast Reload Active!");
        }
        else if(idx == 3 && self verifyCash(500))
        {
            self setPerk("specialty_movefaster");
            self setPerk("specialty_unlimitedsprint");
            self iPrintlnBold("^2Lightweight & Stamin-Up Active!");
        }
    }
    // 6: GRENADES
    else if(cat == 6)
    {
        if(idx == 0 && self verifyCash(300))
            maps\mp\_ambientpackage::giveGrenade("frag_grenade_mp", 1);
        else if(idx == 1 && self verifyCash(200))
            maps\mp\_ambientpackage::giveGrenade("concussion_grenade_mp", 2);
        else if(idx == 2 && self verifyCash(300))
            maps\mp\_ambientpackage::giveGrenade("willy_pete_mp", 1);
    }
    // 7: KILLSTREAKS
    else if(cat == 7)
    {
        if(idx == 0 && self verifyCash(1500))
            maps\mp\_ambientpackage::giveCustomKillstreak("radar_mp");
        else if(idx == 1 && self verifyCash(2000))
            maps\mp\_ambientpackage::giveCustomKillstreak("rcbomb_mp");
        else if(idx == 2 && self verifyCash(3000))
            maps\mp\_ambientpackage::giveCustomKillstreak("autoturret_mp");
    }
}

equipPrimary(weapon)
{
    primaries = self getWeaponsListPrimaries();
    foreach(w in primaries)
    {
        if(!isSubStr(w, "knife") && !isSubStr(w, "fiveseven") && !isSubStr(w, "judge") && !isSubStr(w, "beretta93r") && !isSubStr(w, "kard") && !isSubStr(w, "fnp45"))
            self takeWeapon(w);
    }

    self giveWeapon(weapon);
    self giveMaxAmmo(weapon);
    self switchToWeapon(weapon);
    self iPrintlnBold("^2Purchased: ^7" + weapon);
}

switchSidearm(pistol)
{
    primaries = self getWeaponsListPrimaries();
    foreach(w in primaries)
    {
        if(isSubStr(w, "fiveseven") || isSubStr(w, "judge") || isSubStr(w, "beretta93r") || isSubStr(w, "kard") || isSubStr(w, "fnp45"))
            self takeWeapon(w);
    }

    self giveWeapon(pistol);
    self giveMaxAmmo(pistol);
    self switchToWeapon(pistol);
    self iPrintlnBold("^2Sidearm Equipped: ^7" + pistol);
}

verifyCash(cost)
{
    if(self.money >= cost)
    {
        self.money -= cost;
        self iPrintlnBold("^2Purchased! (-$" + cost + ")");
        return true;
    }
    self iPrintlnBold("^1Insufficient Funds! ($" + cost + " required)");
    return false;
}