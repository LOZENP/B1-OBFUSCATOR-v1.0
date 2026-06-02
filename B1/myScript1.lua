--[[
    EPIC TEXT RPG - Dungeon Crawler Deluxe
    A complete RPG system for Lua 5.1
--]]

math.randomseed(os.time())

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function table_contains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then return true end
    end
    return false
end

local function table_copy(original)
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            copy[k] = table_copy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function weighted_random(weights)
    local total = 0
    for _, w in ipairs(weights) do total = total + w end
    local roll = math.random() * total
    local running = 0
    for i, w in ipairs(weights) do
        running = running + w
        if roll <= running then return i end
    end
    return 1
end

-- ============================================
-- GAME DATA
-- ============================================

local classes = {
    warrior = {
        name = "Warrior",
        hp_base = 120,
        mp_base = 50,
        str_base = 18,
        agi_base = 12,
        int_base = 8,
        skills = {"Slash", "Shield Bash", "Rage"},
        description = "High HP and strength, uses heavy weapons"
    },
    mage = {
        name = "Mage",
        hp_base = 70,
        mp_base = 120,
        str_base = 6,
        agi_base = 10,
        int_base = 20,
        skills = {"Fireball", "Ice Bolt", "Heal"},
        description = "Powerful spells but fragile"
    },
    rogue = {
        name = "Rogue",
        hp_base = 85,
        mp_base = 80,
        str_base = 12,
        agi_base = 20,
        int_base = 10,
        skills = {"Backstab", "Poison", "Evasion"},
        description = "Fast and deadly, high critical chance"
    }
}

local weapons = {
    {name = "Rusty Sword", damage = {8, 14}, value = 50, class = "warrior"},
    {name = "Wooden Staff", damage = {5, 10}, value = 40, class = "mage"},
    {name = "Iron Dagger", damage = {7, 12}, value = 45, class = "rogue"},
    {name = "Steel Greatsword", damage = {15, 25}, value = 200, class = "warrior"},
    {name = "Crystal Wand", damage = {12, 20}, value = 180, class = "mage"},
    {name = "Venomfang", damage = {10, 18}, value = 190, class = "rogue"},
    {name = "Dragon's Bane", damage = {25, 40}, value = 500, class = "warrior"},
    {name = "Archmage Staff", damage = {20, 35}, value = 480, class = "mage"},
    {name = "Shadow Blade", damage = {18, 30}, value = 450, class = "rogue"}
}

local armors = {
    {name = "Leather Armor", defense = 5, value = 60},
    {name = "Chainmail", defense = 10, value = 150},
    {name = "Iron Plate", defense = 15, value = 300},
    {name = "Mystic Robe", defense = 8, value = 200},
    {name = "Dragon Scale", defense = 25, value = 600}
}

local potions = {
    health_small = {name = "Minor Health Potion", effect = 30, cost = 30, type = "health"},
    health_large = {name = "Major Health Potion", effect = 60, cost = 70, type = "health"},
    mana_small = {name = "Minor Mana Potion", effect = 25, cost = 25, type = "mana"},
    mana_large = {name = "Major Mana Potion", effect = 50, cost = 60, type = "mana"}
}

-- ============================================
-- MONSTER DATABASE
-- ============================================

local monsters = {
    -- Tier 1 (Levels 1-3)
    {name = "Slime", hp = 30, mp = 0, attack = 8, defense = 3, exp = 40, gold = {15, 30}, tier = 1,
     abilities = {"slimy_touch"}, description = "A jiggling blob of goo"},
    
    {name = "Goblin", hp = 45, mp = 10, attack = 10, defense = 5, exp = 60, gold = {25, 45}, tier = 1,
     abilities = {"weak_strike"}, description = "A small green creature with a dagger"},
    
    {name = "Bat", hp = 25, mp = 0, attack = 12, defense = 2, exp = 35, gold = {10, 25}, tier = 1,
     abilities = {"sonic_scream"}, description = "A giant cave bat"},
    
    -- Tier 2 (Levels 4-6)
    {name = "Orc", hp = 75, mp = 20, attack = 15, defense = 8, exp = 100, gold = {50, 80}, tier = 2,
     abilities = {"power_strike", "war_cry"}, description = "A brutish orc warrior"},
    
    {name = "Dark Mage", hp = 55, mp = 70, attack = 18, defense = 5, exp = 120, gold = {60, 90}, tier = 2,
     abilities = {"dark_bolt", "curse"}, description = "A hooded figure wielding dark magic"},
    
    {name = "Wolf", hp = 60, mp = 0, attack = 16, defense = 6, exp = 90, gold = {40, 70}, tier = 2,
     abilities = {"rend"}, description = "A ferocious black wolf"},
    
    -- Tier 3 (Levels 7-9)
    {name = "Troll", hp = 120, mp = 30, attack = 22, defense = 12, exp = 180, gold = {100, 150}, tier = 3,
     abilities = {"regeneration", "crushing_blow"}, description = "A massive troll with a club"},
    
    {name = "Vampire", hp = 90, mp = 80, attack = 20, defense = 10, exp = 200, gold = {120, 180}, tier = 3,
     abilities = {"life_drain", "bat_form"}, description = "A pale noble with sharp fangs"},
    
    {name = "Golem", hp = 150, mp = 0, attack = 25, defense = 18, exp = 220, gold = {80, 120}, tier = 3,
     abilities = {"earthquake"}, description = "A living statue of stone"},
    
    -- Tier 4 (Levels 10+)
    {name = "Dragon", hp = 250, mp = 100, attack = 35, defense = 20, exp = 500, gold = {300, 500}, tier = 4,
     abilities = {"fire_breath", "wing_storm", "fear_roar"}, description = "A fearsome red dragon"},
    
    {name = "Lich", hp = 180, mp = 150, attack = 30, defense = 15, exp = 450, gold = {250, 400}, tier = 4,
     abilities = {"soul_drain", "summon_undead", "frost_nova"}, description = "An undead sorcerer"},
    
    {name = "Demon Lord", hp = 300, mp = 120, attack = 40, defense = 25, exp = 800, gold = {500, 800}, tier = 4,
     abilities = {"hellfire", "dark_pact", "chaos_bolt"}, description = "A powerful demon from the abyss"}
}

-- ============================================
-- ABILITY SYSTEM
-- ============================================

local abilities = {
    -- Player abilities
    slash = {
        name = "Slash", cost = 0, type = "physical",
        execute = function(user, target)
            local damage = user.strength + math.random(5, 15)
            return damage, "You slash at the " .. target.name .. "!"
        end
    },
    shield_bash = {
        name = "Shield Bash", cost = 15, type = "physical",
        execute = function(user, target)
            local damage = user.strength * 1.5 + math.random(10, 20)
            return damage, "You bash the " .. target.name .. " with your shield!"
        end
    },
    rage = {
        name = "Rage", cost = 20, type = "buff",
        execute = function(user, target)
            user.buffs = user.buffs or {}
            user.buffs.rage = {remaining = 3, multiplier = 1.5}
            return 0, "You enter a rage! Damage increased for 3 turns!"
        end
    },
    fireball = {
        name = "Fireball", cost = 25, type = "magic",
        execute = function(user, target)
            local damage = user.intelligence * 2 + math.random(15, 30)
            return damage, "You hurl a blazing fireball at the " .. target.name .. "!"
        end
    },
    ice_bolt = {
        name = "Ice Bolt", cost = 20, type = "magic",
        execute = function(user, target)
            local damage = user.intelligence * 1.8 + math.random(10, 25)
            return damage, "A shard of ice strikes the " .. target.name .. "!"
        end
    },
    heal = {
        name = "Heal", cost = 30, type = "support",
        execute = function(user, target)
            local healing = user.intelligence * 1.5 + math.random(20, 40)
            user.hp = math.min(user.max_hp, user.hp + healing)
            return 0, "You restore " .. healing .. " HP with healing magic!"
        end
    },
    backstab = {
        name = "Backstab", cost = 15, type = "physical",
        execute = function(user, target)
            local damage = user.strength * 2 + user.agility + math.random(15, 25)
            return damage, "You strike from the shadows, piercing vital points!"
        end
    },
    poison = {
        name = "Poison", cost = 15, type = "debuff",
        execute = function(user, target)
            target.buffs = target.buffs or {}
            target.buffs.poison = {remaining = 3, damage = math.floor(target.max_hp * 0.05)}
            return 5, "You coat your blade in poison, weakening the " .. target.name .. "!"
        end
    },
    evasion = {
        name = "Evasion", cost = 20, type = "buff",
        execute = function(user, target)
            user.buffs = user.buffs or {}
            user.buffs.evasion = {remaining = 3, chance = 0.5}
            return 0, "You become light on your feet, evading attacks!"
        end
    },
    
    -- Monster abilities
    slimy_touch = {
        name = "Slimy Touch", execute = function(user, target)
            local damage = user.attack + math.random(1, 8)
            return damage, user.name .. " oozes onto you!"
        end
    },
    weak_strike = {
        name = "Weak Strike", execute = function(user, target)
            local damage = user.attack + math.random(2, 10)
            return damage, user.name .. " stabs at you!"
        end
    },
    sonic_scream = {
        name = "Sonic Scream", execute = function(user, target)
            local damage = user.attack + math.random(3, 12)
            return damage, user.name .. " emits a piercing screech!"
        end
    },
    power_strike = {
        name = "Power Strike", execute = function(user, target)
            local damage = user.attack * 1.8 + math.random(5, 15)
            return damage, user.name .. " swings with tremendous force!"
        end
    },
    war_cry = {
        name = "War Cry", execute = function(user, target)
            user.attack = user.attack + 5
            return 0, user.name .. " roars, increasing its attack!"
        end
    },
    dark_bolt = {
        name = "Dark Bolt", execute = function(user, target)
            local damage = user.magic + math.random(8, 20)
            return damage, user.name .. " shoots a bolt of dark energy!"
        end
    },
    curse = {
        name = "Curse", execute = function(user, target)
            target.buffs = target.buffs or {}
            target.buffs.curse = {remaining = 3, penalty = 0.7}
            return 0, user.name .. " curses you! Your damage is reduced!"
        end
    },
    rend = {
        name = "Rend", execute = function(user, target)
            local damage = user.attack + math.random(5, 18)
            return damage, user.name .. " tears into you with sharp claws!"
        end
    },
    regeneration = {
        name = "Regeneration", execute = function(user, target)
            local heal = math.floor(user.max_hp * 0.1)
            user.hp = math.min(user.max_hp, user.hp + heal)
            return 0, user.name .. " regenerates " .. heal .. " HP!"
        end
    },
    crushing_blow = {
        name = "Crushing Blow", execute = function(user, target)
            local damage = user.attack * 2 + math.random(10, 25)
            return damage, user.name .. " brings down a devastating blow!"
        end
    },
    life_drain = {
        name = "Life Drain", execute = function(user, target)
            local damage = user.magic + math.random(10, 22)
            user.hp = math.min(user.max_hp, user.hp + math.floor(damage/2))
            return damage, user.name .. " drains your life force!"
        end
    },
    bat_form = {
        name = "Bat Form", execute = function(user, target)
            user.evasion = 0.7
            return 0, user.name .. " turns into a swarm of bats!"
        end
    },
    earthquake = {
        name = "Earthquake", execute = function(user, target)
            local damage = user.attack * 1.5 + math.random(15, 30)
            return damage, user.name .. " stomps, shaking the ground violently!"
        end
    },
    fire_breath = {
        name = "Fire Breath", execute = function(user, target)
            local damage = user.attack * 1.8 + math.random(20, 40)
            return damage, user.name .. " breathes a torrent of flames!"
        end
    },
    wing_storm = {
        name = "Wing Storm", execute = function(user, target)
            local damage = user.attack * 1.3 + math.random(10, 25)
            return damage, user.name .. " creates a storm with its wings!"
        end
    },
    fear_roar = {
        name = "Fear Roar", execute = function(user, target)
            target.buffs = target.buffs or {}
            target.buffs.fear = {remaining = 2, miss_chance = 0.3}
            return 0, user.name .. " roars, filling you with fear!"
        end
    },
    soul_drain = {
        name = "Soul Drain", execute = function(user, target)
            local damage = user.magic + math.random(15, 35)
            user.hp = math.min(user.max_hp, user.hp + math.floor(damage))
            return damage, user.name .. " tears at your very soul!"
        end
    },
    summon_undead = {
        name = "Summon Undead", execute = function(user, target)
            return 10, user.name .. " summons skeletal minions!"
        end
    },
    frost_nova = {
        name = "Frost Nova", execute = function(user, target)
            local damage = user.magic * 1.5 + math.random(10, 30)
            return damage, user.name .. " unleashes a blast of freezing cold!"
        end
    },
    hellfire = {
        name = "Hellfire", execute = function(user, target)
            local damage = user.attack * 2 + math.random(25, 50)
            return damage, user.name .. " conjures flames from the abyss!"
        end
    },
    dark_pact = {
        name = "Dark Pact", execute = function(user, target)
            user.attack = user.attack * 1.5
            user.hp = math.floor(user.hp * 0.8)
            return 0, user.name .. " sacrifices HP for demonic power!"
        end
    },
    chaos_bolt = {
        name = "Chaos Bolt", execute = function(user, target)
            local damage = user.magic * 2.5 + math.random(20, 45)
            return damage, user.name .. " hurls a chaotic bolt of energy!"
        end
    }
}

-- ============================================
-- SHOP SYSTEM
-- ============================================

local Shop = {}
Shop.__index = Shop

function Shop.new()
    local self = setmetatable({}, Shop)
    self.inventory = {}
    return self
end

function Shop:restock(level)
    self.inventory = {}
    
    -- Add potions
    if math.random() < 0.7 then
        table.insert(self.inventory, potions.health_small)
    end
    if math.random() < 0.5 then
        table.insert(self.inventory, potions.health_large)
    end
    if math.random() < 0.7 then
        table.insert(self.inventory, potions.mana_small)
    end
    if math.random() < 0.5 then
        table.insert(self.inventory, potions.mana_large)
    end
    
    -- Add weapons based on level
    for _, weapon in ipairs(weapons) do
        if weapon.value <= level * 100 and math.random() < 0.3 then
            table.insert(self.inventory, weapon)
        end
    end
    
    -- Add armors based on level
    for _, armor in ipairs(armors) do
        if armor.value <= level * 150 and math.random() < 0.3 then
            table.insert(self.inventory, armor)
        end
    end
end

function Shop:display(player)
    if #self.inventory == 0 then
        print("\nThe shop has nothing for sale right now!")
        return false
    end
    
    print("\n=== WELCOME TO THE TRAVELING MERCHANT ===")
    print("Your gold: " .. player.gold)
    print("\nItems for sale:")
    print("----------------------------------------")
    
    for i, item in ipairs(self.inventory) do
        if item.damage then
            print(i .. ". " .. item.name .. " (Weapon) - Damage: " .. item.damage[1] .. "-" .. item.damage[2] .. " | Cost: " .. item.value .. " gold")
        elseif item.defense then
            print(i .. ". " .. item.name .. " (Armor) - Defense: +" .. item.defense .. " | Cost: " .. item.value .. " gold")
        elseif item.effect then
            print(i .. ". " .. item.name .. " - Heals/Restores: " .. item.effect .. " | Cost: " .. item.cost .. " gold")
        end
    end
    print("----------------------------------------")
    print("B. Back to town")
    
    return true
end

function Shop:buy(player, choice)
    local item = self.inventory[choice]
    if not item then return false, "Invalid item choice!" end
    
    local cost = item.value or item.cost
    if player.gold < cost then
        return false, "Not enough gold!"
    end
    
    player.gold = player.gold - cost
    
    if item.damage then
        player.weapon = item
        player.strength = player.base_strength + math.floor((item.damage[1] + item.damage[2]) / 2)
        print("You bought " .. item.name .. "! Your strength increased!")
    elseif item.defense then
        player.armor = item
        player.defense = player.base_defense + item.defense
        print("You bought " .. item.name .. "! Your defense increased!")
    else
        table.insert(player.inventory, item)
        print("You bought " .. item.name .. "!")
    end
    
    table.remove(self.inventory, choice)
    return true, "Purchase successful!"
end

-- ============================================
-- PLAYER CLASS
-- ============================================

local Player = {}
Player.__index = Player

function Player.new(name, class_type)
    local class = classes[class_type]
    if not class then
        print("Invalid class! Defaulting to Warrior.")
        class = classes.warrior
        class_type = "warrior"
    end
    
    local self = setmetatable({}, Player)
    self.name = name
    self.class = class_type
    self.level = 1
    self.exp = 0
    self.exp_needed = 100
    self.gold = 100
    
    -- Stats
    self.max_hp = class.hp_base
    self.hp = self.max_hp
    self.max_mp = class.mp_base
    self.mp = self.max_mp
    self.base_strength = class.str_base
    self.strength = self.base_strength
    self.agility = class.agi_base
    self.base_intelligence = class.int_base
    self.intelligence = self.base_intelligence
    self.base_defense = 5
    self.defense = self.base_defense
    
    -- Equipment
    self.weapon = nil
    self.armor = nil
    self.inventory = {}
    self.skills = {}
    
    for _, skill in ipairs(class.skills) do
        table.insert(self.skills, skill)
    end
    
    -- Start with a basic weapon
    for _, weapon in ipairs(weapons) do
        if weapon.class == class_type and weapon.value == 50 then
            self.weapon = weapon
            self.strength = self.base_strength + math.floor((weapon.damage[1] + weapon.damage[2]) / 2)
            break
        end
    end
    
    -- Start with 2 health potions
    table.insert(self.inventory, potions.health_small)
    table.insert(self.inventory, potions.health_small)
    
    self.buffs = {}
    
    return self
end

function Player:add_exp(amount)
    self.exp = self.exp + amount
    print("Gained " .. amount .. " XP!")
    
    while self.exp >= self.exp_needed do
        self.exp = self.exp - self.exp_needed
        self:level_up()
    end
end

function Player:level_up()
    self.level = self.level + 1
    self.exp_needed = math.floor(self.exp_needed * 1.2)
    
    local hp_gain = math.random(15, 30)
    local mp_gain = math.random(10, 25)
    local stat_points = 5
    
    self.max_hp = self.max_hp + hp_gain
    self.hp = self.max_hp
    self.max_mp = self.max_mp + mp_gain
    self.mp = self.max_mp
    
    print("\n🌟 LEVEL UP! You are now level " .. self.level .. "! 🌟")
    print("HP +" .. hp_gain .. " | MP +" .. mp_gain)
    
    -- Simple stat allocation (in a real game, player would choose)
    local str_gain = math.floor(stat_points * 0.4)
    local agi_gain = math.floor(stat_points * 0.3)
    local int_gain = stat_points - str_gain - agi_gain
    
    self.base_strength = self.base_strength + str_gain
    self.agility = self.agility + agi_gain
    self.base_intelligence = self.base_intelligence + int_gain
    
    -- Recalculate with equipment
    if self.weapon then
        self.strength = self.base_strength + math.floor((self.weapon.damage[1] + self.weapon.damage[2]) / 2)
    else
        self.strength = self.base_strength
    end
    self.intelligence = self.base_intelligence
    
    print("Strength +" .. str_gain .. " | Agility +" .. agi_gain .. " | Intelligence +" .. int_gain)
end

function Player:use_potion(potion_type)
    local potion = potions[potion_type]
    if not potion then return false end
    
    -- Check if player has the potion
    local index = nil
    for i, item in ipairs(self.inventory) do
        if item.name == potion.name then
            index = i
            break
        end
    end
    
    if not index then
        print("You don't have a " .. potion.name .. "!")
        return false
    end
    
    if potion.type == "health" then
        self.hp = math.min(self.max_hp, self.hp + potion.effect)
        print("You restored " .. potion.effect .. " HP!")
    elseif potion.type == "mana" then
        self.mp = math.min(self.max_mp, self.mp + potion.effect)
        print("You restored " .. potion.effect .. " MP!")
    end
    
    table.remove(self.inventory, index)
    return true
end

function Player:display_stats()
    print("\n=== " .. self.name .. " the " .. classes[self.class].name .. " ===")
    print("Level: " .. self.level .. " | Exp: " .. self.exp .. "/" .. self.exp_needed)
    print("HP: " .. self.hp .. "/" .. self.max_hp)
    print("MP: " .. self.mp .. "/" .. self.max_mp)
    print("Strength: " .. self.strength .. " | Agility: " .. self.agility .. " | Intelligence: " .. self.intelligence)
    print("Defense: " .. self.defense)
    print("Gold: " .. self.gold)
    
    if self.weapon then
        print("Weapon: " .. self.weapon.name)
    end
    if self.armor then
        print("Armor: " .. self.armor.name)
    end
    
    print("\nInventory:")
    local potion_count = {}
    for _, item in ipairs(self.inventory) do
        potion_count[item.name] = (potion_count[item.name] or 0) + 1
    end
    for name, count in pairs(potion_count) do
        print("  " .. name .. " x" .. count)
    end
    
    if #self.inventory == 0 then
        print("  (Empty)")
    end
    
    print("\nSkills:")
    for i, skill in ipairs(self.skills) do
        print("  " .. i .. ". " .. skill .. " (" .. abilities[skill:lower():gsub(" ", "_")].cost .. " MP)")
    end
end

function Player:update_buffs()
    for buff, data in pairs(self.buffs) do
        data.remaining = data.remaining - 1
        if data.remaining <= 0 then
            self.buffs[buff] = nil
            print("The " .. buff .. " effect has worn off.")
        elseif buff == "poison" then
            local damage = data.damage
            self.hp = self.hp - damage
            print("You take " .. damage .. " poison damage!")
        end
    end
end

function Player:get_damage_multiplier()
    local multiplier = 1
    if self.buffs.rage then multiplier = multiplier * self.buffs.rage.multiplier end
    if self.buffs.curse then multiplier = multiplier * self.buffs.curse.penalty end
    return multiplier
end

function Player:get_evasion_chance()
    local chance = 0
    if self.buffs.evasion then chance = self.buffs.evasion.chance end
    if self.buffs.fear then chance = self.buffs.fear.miss_chance end
    return chance
end

-- ============================================
-- MONSTER CLASS
-- ============================================

local Monster = {}
Monster.__index = Monster

function Monster.new(template)
    local self = setmetatable({}, Monster)
    self.template = template
    self.name = template.name
    self.max_hp = template.hp
    self.hp = self.max_hp
    self.max_mp = template.mp
    self.mp = self.max_mp
    self.attack = template.attack
    self.defense = template.defense
    self.magic = math.floor(template.attack * 0.8)
    self.abilities = template.abilities
    self.buffs = {}
    return self
end

function Monster:update_buffs()
    for buff, data in pairs(self.buffs) do
        data.remaining = data.remaining - 1
        if data.remaining <= 0 then
            self.buffs[buff] = nil
        elseif buff == "regeneration" then
            local heal = math.floor(self.max_hp * 0.1)
            self.hp = math.min(self.max_hp, self.hp + heal)
        end
    end
end

function Monster:choose_ability()
    if #self.abilities == 0 then return nil end
    local weights = {0.7, 0.3}
    for i = 3, #self.abilities do weights[i] = 0.1 end
    local index = weighted_random(weights)
    return self.abilities[math.min(index, #self.abilities)]
end

function Monster:get_damage_multiplier()
    return 1
end

-- ============================================
-- COMBAT SYSTEM
-- ============================================

local function execute_combat(player, monster)
    print("\n⚔️ COMBAT STARTED ⚔️")
    print("A level " .. monster.template.tier .. " " .. monster.name .. " appears!")
    print(monster.template.description)
    print("----------------------------------------")
    
    local turn = 1
    local player_turn_boost = player.agility > 15
    
    while player.hp > 0 and monster.hp > 0 do
        print("\n--- Turn " .. turn .. " ---")
        print(monster.name .. " HP: " .. math.max(0, monster.hp) .. "/" .. monster.max_hp)
        print(player.name .. " HP: " .. player.hp .. "/" .. player.max_hp .. " | MP: " .. player.mp .. "/" .. player.max_mp)
        
        -- Player action
        local action_valid = false
        while not action_valid do
            print("\nWhat will you do?")
            print("1. Attack")
            print("2. Use Skill")
            print("3. Use Potion")
            print("4. Run Away")
            
            local choice = io.read()
            
            if choice == "1" then
                -- Normal attack
                local damage = player.strength + math.random(5, 20)
                local damage_mult = player:get_damage_multiplier()
                damage = math.floor(damage * damage_mult)
                damage = math.max(1, damage - monster.defense)
                
                monster.hp = monster.hp - damage
                print("You attack for " .. damage .. " damage!")
                action_valid = true
                
            elseif choice == "2" then
                -- Skill menu
                print("\nSelect skill:")
                for i, skill_name in ipairs(player.skills) do
                    local skill_key = skill_name:lower():gsub(" ", "_")
                    local skill = abilities[skill_key]
                    print(i .. ". " .. skill_name .. " (" .. skill.cost .. " MP)")
                end
                
                local skill_choice = tonumber(io.read())
                if skill_choice and skill_choice >= 1 and skill_choice <= #player.skills then
                    local skill_name = player.skills[skill_choice]
                    local skill_key = skill_name:lower():gsub(" ", "_")
                    local skill = abilities[skill_key]
                    
                    if player.mp >= skill.cost then
                        player.mp = player.mp - skill.cost
                        local damage, message = skill.execute(player, monster)
                        print(message)
                        if damage and damage > 0 then
                            monster.hp = monster.hp - damage
                            print("Dealt " .. damage .. " damage!")
                        end
                        action_valid = true
                    else
                        print("Not enough MP! You need " .. skill.cost .. " MP.")
                    end
                else
                    print("Invalid skill choice!")
                end
                
            elseif choice == "3" then
                -- Potion menu
                print("\nSelect potion:")
                local potions_available = {}
                for _, item in ipairs(player.inventory) do
                    if item.type then
                        if not table_contains(potions_available, item.name) then
                            table.insert(potions_available, item.name)
                        end
                    end
                end
                
                if #potions_available == 0 then
                    print("You have no potions!")
                else
                    for i, potion_name in ipairs(potions_available) do
                        print(i .. ". " .. potion_name)
                    end
                    local potion_choice = tonumber(io.read())
                    if potion_choice and potion_choice >= 1 and potion_choice <= #potions_available then
                        local potion_name = potions_available[potion_choice]
                        local potion = nil
                        for _, p in pairs(potions) do
                            if p.name == potion_name then
                                potion = p
                                break
                            end
                        end
                        if potion and player:use_potion(potion_name) then
                            action_valid = true
                        end
                    end
                end
                
            elseif choice == "4" then
                local escape_chance = 0.5 + (player.agility / 100)
                if math.random() < escape_chance then
                    print("You successfully escaped!")
                    return false
                else
                    print("Failed to escape!")
                    action_valid = true
                end
            else
                print("Invalid choice!")
            end
        end
        
        if monster.hp <= 0 then
            print("\n✨ VICTORY! ✨")
            local gold_reward = math.random(monster.template.gold[1], monster.template.gold[2])
            player.gold = player.gold + gold_reward
            print("You gained " .. gold_reward .. " gold!")
            player:add_exp(monster.template.exp)
            
            -- Chance for loot
            if math.random() < 0.15 then
                local loot_options = {potions.health_small, potions.mana_small}
                local loot = loot_options[math.random(#loot_options)]
                table.insert(player.inventory, loot)
                print("You found a " .. loot.name .. "!")
            end
            
            return true
        end
        
        -- Monster turn
        print("\n" .. monster.name .. "'s turn:")
        
        -- Apply monster buffs
        monster:update_buffs()
        
        -- Choose ability
        local ability_name = monster:choose_ability()
        local ability = abilities[ability_name]
        
        if ability and monster.mp >= (ability.cost or 0) then
            local damage, message = ability.execute(monster, player)
            print(message)
            
            if damage and damage > 0 then
                -- Check evasion
                if math.random() < player:get_evasion_chance() then
                    print("You evaded the attack!")
                    damage = 0
                else
                    local damage_mult = monster:get_damage_multiplier()
                    damage = math.floor(damage * damage_mult)
                    damage = math.max(1, damage - player.defense)
                end
                
                if damage > 0 then
                    player.hp = player.hp - damage
                    print(monster.name .. " deals " .. damage .. " damage!")
                end
            end
            
            if ability.cost then
                monster.mp = monster.mp - ability.cost
            end
        else
            -- Basic attack
            local damage = math.max(1, monster.attack + math.random(1, 10) - player.defense)
            if math.random() < player:get_evasion_chance() then
                print("You evaded the attack!")
                damage = 0
            else
                print(monster.name .. " attacks!")
            end
            if damage > 0 then
                player.hp = player.hp - damage
                print(monster.name .. " deals " .. damage .. " damage!")
            end
        end
        
        player:update_buffs()
        turn = turn + 1
    end
    
    if player.hp <= 0 then
        print("\n💀 GAME OVER - You were defeated by " .. monster.name .. "! 💀")
        return false
    end
    
    return true
end

-- ============================================
-- WORLD MAP & DUNGEON SYSTEM
-- ============================================

local WorldMap = {}
WorldMap.__index = WorldMap

function WorldMap.new()
    local self = setmetatable({}, WorldMap)
    self.locations = {
        {name = "Town", unlocked = true, type = "town"},
        {name = "Forest", unlocked = true, type = "dungeon", tier = 1},
        {name = "Caves", unlocked = false, type = "dungeon", tier = 2, requirement = 3},
        {name = "Mountain", unlocked = false, type = "dungeon", tier = 3, requirement = 6},
        {name = "Dark Temple", unlocked = false, type = "dungeon", tier = 4, requirement = 10}
    }
    return self
end

function WorldMap:unlock_locations(level)
    for _, location in ipairs(self.locations) do
        if location.requirement and level >= location.requirement then
            location.unlocked = true
        end
    end
end

function WorldMap:display(player)
    print("\n=== WORLD MAP ===")
    print("Current Level: " .. player.level)
    print("\nLocations:")
    for i, location in ipairs(self.locations) do
        local status = location.unlocked and "✓" or "🔒"
        local req = location.requirement and " (Req Lv." .. location.requirement .. ")" or ""
        print(i .. ". " .. status .. " " .. location.name .. req)
    end
end

function WorldMap:travel(player, choice)
    local location = self.locations[choice]
    if not location then
        print("Invalid location!")
        return false
    end
    
    if not location.unlocked then
        print("This location is locked! Reach level " .. location.requirement .. " to unlock.")
        return false
    end
    
    print("\nTraveling to " .. location.name .. "...")
    
    if location.type == "town" then
        self:enter_town(player)
    else
        self:enter_dungeon(player, location)
    end
    
    return true
end

function WorldMap:enter_town(player)
    local shop = Shop.new()
    local in_town = true
    
    while in_town do
        print("\n=== TOWN ===")
        print("What would you like to do?")
        print("1. Visit Shop")
        print("2. Rest at Inn (Restore HP/MP - 50 gold)")
        print("3. Check Stats")
        print("4. Leave Town")
        
        local choice = io.read()
        
        if choice == "1" then
            shop:restock(player.level)
            if shop:display(player) then
                local buy_choice = io.read()
                if buy_choice:lower() == "b" then
                    -- Back
                else
                    local num = tonumber(buy_choice)
                    if num then
                        local success, msg = shop:buy(player, num)
                        print(msg)
                    end
                end
            end
            
        elseif choice == "2" then
            if player.gold >= 50 then
                player.gold = player.gold - 50
                player.hp = player.max_hp
                player.mp = player.max_mp
                print("You rest at the inn. HP and MP fully restored!")
            else
                print("Not enough gold! Need 50 gold.")
            end
            
        elseif choice == "3" then
            player:display_stats()
            
        elseif choice == "4" then
            in_town = false
            print("You leave the town.")
        else
            print("Invalid choice!")
        end
    end
end

function WorldMap:enter_dungeon(player, location)
    print("\nEntering " .. location.name .. "...")
    print("You venture into the unknown...")
    
    local floors = 3 + math.floor(player.level / 3)
    local monsters_in_tier = {}
    
    for _, monster in pairs(monsters) do
        if monster.tier == location.tier then
            table.insert(monsters_in_tier, monster)
        end
    end
    
    if #monsters_in_tier == 0 then
        print("No monsters found in this area!")
        return
    end
    
    for floor = 1, floors do
        print("\n" .. string.rep("-", 40))
        print("FLOOR " .. floor .. " of " .. floors)
        print(string.rep("-", 40))
        
        local monster_template = monsters_in_tier[math.random(#monsters_in_tier)]
        local monster = Monster.new(monster_template)
        
        local victory = execute_combat(player, monster)
        
        if not victory then
            print("\nYour adventure ends here...")
            return
        end
        
        -- Heal partially between floors
        local heal_amount = math.floor(player.max_hp * 0.2)
        player.hp = math.min(player.max_hp, player.hp + heal_amount)
        local mana_heal = math.floor(player.max_mp * 0.15)
        player.mp = math.min(player.max_mp, player.mp + mana_heal)
        print("\nYou catch your breath and recover " .. heal_amount .. " HP and " .. mana_heal .. " MP.")
        
        -- Chance for treasure chest
        if math.random() < 0.2 then
            local chest_gold = math.random(50, 150) * location.tier
            player.gold = player.gold + chest_gold
            print("🎁 You found a treasure chest! +" .. chest_gold .. " gold! 🎁")
        end
    end
    
    print("\n🏆 Congratulations! You cleared " .. location.name .. "! 🏆")
    local completion_bonus = 100 * location.tier
    player:add_exp(completion_bonus)
    print("Clear bonus: +" .. completion_bonus .. " XP!")
end

-- ============================================
-- MAIN GAME LOOP
-- ============================================

local function main()
    print([[

    ╔═══════════════════════════════════════╗
    ║     EPIC TEXT RPG - DELUXE EDITION    ║
    ║         Dungeon Crawler v2.0          ║
    ╚═══════════════════════════════════════╝
    
    Welcome, adventurer!
    ]])
    
    print("What is your name?")
    local name = io.read()
    if name == "" then name = "Hero" end
    
    print("\nChoose your class:")
    for key, class in pairs(classes) do
        print(key .. ". " .. class.name .. " - " .. class.description)
    end
    
    local class_choice = io.read():lower()
    if not classes[class_choice] then
        print("Invalid choice! Defaulting to Warrior.")
        class_choice = "warrior"
    end
    
    local player = Player.new(name, class_choice)
    local world = WorldMap.new()
    
    local playing = true
    while playing do
        world:unlock_locations(player.level)
        world:display(player)
        
        print("\nWhat would you like to do?")
        print("1. Travel to location")
        print("2. Check Stats")
        print("3. Quit Game")
        
        local choice = io.read()
        
        if choice == "1" then
            print("Enter location number:")
            local loc_num = tonumber(io.read())
            if loc_num then
                world:travel(player, loc_num)
            else
                print("Invalid number!")
            end
        elseif choice == "2" then
            player:display_stats()
        elseif choice == "3" then
            print("\nThank you for playing! Farewell, " .. player.name .. "!")
            playing = false
        else
            print("Invalid choice!")
        end
        
        if player.hp <= 0 then
            print("\nGame Over!")
            playing = false
        end
    end
end

-- Run the game
main()
