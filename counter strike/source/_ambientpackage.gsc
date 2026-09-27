#include maps\mp\_utility;
#include common_scripts\utility;

init()
{
    level.ambient_modifier = [];
}

// =========================================================================
// UTILITÁRIOS, EQUIPAMENTOS E KILLSTREAKS CS
// =========================================================================

spawnScriptModel(model, origin, angles)
{
    ent = spawn("script_model", origin, 1);
    ent setModel(model);
    if(isDefined(angles))
        ent.angles = angles;
    return ent;
}

// Concede killstreaks com os identificadores oficiais da engine do BO2
giveCustomKillstreak(streakName)
{
    self setActionSlot(4, "killstreak");
    self maps\mp\killstreaks\_killstreaks::givekillstreak(streakName, false, false, self);
    self iPrintlnBold("^2Killstreak Ready! Press [{+actionslot 4}] to Deploy.");
}

// Concede granadas com reposição correta de pente
giveGrenade(weaponName, count)
{
    self takeWeapon(weaponName);
    self giveWeapon(weaponName);
    self setWeaponAmmoClip(weaponName, count);
    self switchToWeapon(weaponName);
    self iPrintlnBold("^2Purchased: ^7" + weaponName);
}

// Concede armas com attachments oficiais sem corromper o inventário
giveWeaponWithAttachments(baseWeapon, att1, att2)
{
    weaponString = baseWeapon;
    if(isDefined(att1) && att1 != "")
        weaponString = weaponString + "+" + att1;
    if(isDefined(att2) && att2 != "")
        weaponString = weaponString + "+" + att2;

    primaries = self getWeaponsListPrimaries();
    foreach(w in primaries)
    {
        if(!isSubStr(w, "knife") && !isSubStr(w, "fiveseven") && !isSubStr(w, "fnp45") && !isSubStr(w, "judge") && !isSubStr(w, "beretta93r") && !isSubStr(w, "kard"))
            self takeWeapon(w);
    }

    self giveWeapon(weaponString);
    self giveMaxAmmo(weaponString);
    self switchToWeapon(weaponString);
    self iPrintlnBold("^2Tactical Weapon: ^7" + weaponString);
}