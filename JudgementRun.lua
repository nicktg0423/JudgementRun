--- JudgementRun
--- Judgement replaces the Joker everywhere in the game. Any effect that would
--- create a Joker creates a Judgement instead, so every Joker you end up with
--- is one Judgement rolled at random. You never choose a single one.
---
--- Verified against the project's vanilla source. Every Joker-creation site:
---
---   card.lua:1418  Judgement AND The Soul   keys 'jud' / 'sou'
---   card.lua:1457  Wraith                   key  'wra'
---   card.lua:1774  Buffoon Pack contents    key  'buf'
---   card.lua:2535  Riff-raff                key  'rif'
---   tag.lua:138    Top-up Tag               key  'top'
---   tag.lua:356    Rare Tag                 key  'rta'
---   tag.lua:370    Uncommon Tag             key  'uta'
---
---   plus the shop, which fills slots by weight from G.GAME.joker_rate = 20
---   against tarot_rate 4 / planet_rate 4 / spectral_rate 0 (game.lua:1901),
---   routed through create_card_for_shop.
---
--- All of them bottom out in create_card('Joker', ...) (common_events.lua:2082),
--- so ONE wrapper on create_card covers the entire rule. We convert every
--- 'Joker' request except Judgement's own, which must keep producing a Joker
--- or nothing in the run ever produces one.
---
--- forced_key short-circuits the pool entirely (common_events.lua:2109) and
--- rewrites _type from the center's set, so forcing 'c_judgement' returns a
--- real Tarot-set Judgement rather than a Joker wearing its art.
---
--- DESTINATION IS THE SECOND HALF OF THE PROBLEM. Four of those call sites
--- hard-code G.jokers as the destination and emplace there straight after.
--- A Judgement is a consumable, so it has to land in G.consumeables instead.
--- CardArea:emplace is wrapped to redirect, and to drop the card outright when
--- consumable slots are full, which is Nick's rule: no room means it is simply
--- not produced. The shop, packs and the shop-targeted tags need no redirect
--- because those areas already display consumables natively.
---
--- v1.1.0, after the first test run played far too easy.
---
---   Judgement's base cost is $3 (game.lua:553). That number was balanced for a
---   card that is 1 of about 22 Tarots and therefore rarely seen. This mod puts
---   it in every Joker slot in the shop, so a $3 card became the entire Joker
---   economy. The rarity roll it grants (common_events.lua:1970) is 70% Common,
---   25% Uncommon, 5% Rare, against real Joker prices of $2 to $10. Paying $3
---   for roughly $5 of Joker, every shop, is why the run had no pressure.
---
---   The consumable slot limit was expected to throttle this and does not,
---   because a Judgement is used the instant it is bought and never occupies a
---   slot at all.
---
---   Fix is to price the card for what it delivers and to stop inflating Joker
---   slots. base_cost is overridden on Card:set_cost rather than by mutating
---   G.P_CENTERS, so the change is live-toggleable and leaks into nothing else.
---
---   ETERNAL WAS CONSIDERED AND REJECTED, with a reason worth keeping:
---   Card:can_use_consumeable (card.lua:1557) blocks Judgement entirely while
---   Joker slots are full. Making the granted Jokers Eternal would lock the
---   board early and leave every Judgement in the shop greyed out for the rest
---   of the run, which is a dead shop and no decisions.
---
--- v1.3.0, after Nick played it on Gold Stake.
---
---   The reprice is off by default now. Judgement is back to its vanilla $3.
---
---   The v1.1.0 economics above are still correct as economics: $3 for roughly
---   $5 of Joker is underpriced in isolation. What that analysis missed is that
---   it was measured on a low stake, where nothing else in the run is applying
---   pressure. On Gold Stake the difficulty is already coming from the stake,
---   and $7 on top of that made the run harder than the concept needs to be.
---   The price was doing a job the stake was already doing.
---
---   Both the slot cut and the reprice were adopted together as one difficulty
---   package. Only the reprice is being reverted; joker_slots stays at 5,
---   because the ten-slot problem was that every slot got filled cheaply, not
---   that the cards were mispriced.
---
---   Kept as a toggle rather than deleted. If a future episode runs on a lower
---   stake, "Price Judgement at what it grants" in the mod config turns it back
---   on and cfg.judgement_cost is still 7.
---
--- v1.4.0, after the Ep 015 run.
---
---   Riff-raff produced nothing in the recorded run and the cause was not
---   found, so it is removed from the pool by default. See the ban section
---   below for what was ruled out. This is containment, not a fix, and the
---   toggle exists so the ban can come off the moment the real cause is known.

--- Stable mod reference captured at load time (SMODS.current_mod is nil later).
local THIS_MOD = SMODS.current_mod

THIS_MOD.config = THIS_MOD.config or {}
local cfg = THIS_MOD.config
if cfg.enabled         == nil then cfg.enabled         = true  end
if cfg.joker_slots     == nil then cfg.joker_slots     = 5     end
if cfg.judgement_cost  == nil then cfg.judgement_cost  = 7     end
if cfg.reprice         == nil then cfg.reprice         = false end
if cfg.convert_soul    == nil then cfg.convert_soul    = true  end
if cfg.ban_riffraff    == nil then cfg.ban_riffraff    = true  end

--- SMODS writes this table to config/JudgementRun.jkr and reloads it on every
--- launch, so an `== nil` default NEVER fires again once a key has been saved.
--- v1.0.0 shipped joker_slots = 10; changing the default in v1.1.0 did nothing
--- because the old 10 was still on disk. Bump CONFIG_VERSION whenever a shipped
--- default changes and migrate the affected keys explicitly here.
---
--- Migrations are cumulative and each one is gated on the version it belongs
--- to. The v2 block used to re-run on every bump, which would have silently
--- reset a deliberately changed joker_slots the next time any other default
--- moved. Stepwise gating means a config on v1 gets both, a config on v2 gets
--- only v3, and nothing gets clobbered twice.
---
--- A BRAND NEW key does NOT need a version bump. ban_riffraff was added in
--- v1.4.0 and is absent from every saved config, so its `== nil` default fires
--- normally on the next launch. Only a CHANGED default needs a migration.
local CONFIG_VERSION = 3
if cfg.cfg_version ~= CONFIG_VERSION then
    local from = cfg.cfg_version or 0
    if from < 2 then
        cfg.joker_slots = 5      -- v2: ten slots made the run trivially easy
    end
    if from < 3 then
        cfg.reprice = false      -- v3: Gold Stake supplies the pressure itself
    end
    cfg.cfg_version = CONFIG_VERSION
end

local function on() return cfg.enabled end

--- Judgement's own seed key. The one exemption.
local JUDGEMENT_KEY = 'jud'
local SOUL_KEY      = 'sou'

--- Documentation only. The wrapper converts by exclusion, not by this list,
--- so the shop is caught whatever key create_card_for_shop passes.
local KNOWN_SOURCES = {
    sou = 'The Soul', wra = 'Wraith',      buf = 'Buffoon Pack',
    rif = 'Riff-raff', top = 'Top-up Tag', rta = 'Rare Tag', uta = 'Uncommon Tag',
}

--- Only convert inside real gameplay areas. The collection and demo views also
--- build Jokers and must keep showing Jokers.
local function is_live_area(area)
    return area == G.jokers or area == G.consumeables
        or area == G.shop_jokers or area == G.pack_cards
end

--- Free consumable slots right now. This is the real constraint for every
--- converted source, because a Judgement lands in G.consumeables.
local function consumable_room()
    if not G.consumeables or not G.consumeables.config then return 0 end
    return G.consumeables.config.card_limit
           - #G.consumeables.cards
           - (G.GAME.consumeable_buffer or 0)
end

----------------------------------------------------------------------
-- Core: every Joker request becomes a Judgement, except Judgement's own.
----------------------------------------------------------------------
local ref_create_card = create_card

function create_card(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append)
    if on()
       and _type == 'Joker'
       and not forced_key
       and key_append ~= JUDGEMENT_KEY
       and is_live_area(area or G.jokers)
       and not (key_append == SOUL_KEY and not cfg.convert_soul)
    then
        -- soulable is dropped: a Judgement standing in for a Joker should not
        -- itself roll into The Soul.
        return ref_create_card('Tarot', area, nil, nil, skip_materialize, nil,
                               'c_judgement', key_append)
    end
    return ref_create_card(_type, area, legendary, _rarity, skip_materialize,
                           soulable, forced_key, key_append)
end

----------------------------------------------------------------------
-- Destination: a consumable aimed at the Joker row goes to consumables,
-- or is dropped when there is no room.
----------------------------------------------------------------------
local ref_emplace = CardArea.emplace

function CardArea:emplace(card, location, stay_flipped)
    if on() and self == G.jokers and card and card.ability and card.ability.consumeable then
        local cons = G.consumeables
        local buffer = G.GAME.consumeable_buffer or 0
        if cons and (#cons.cards + buffer) < cons.config.card_limit then
            return ref_emplace(cons, card, location, stay_flipped)
        end
        -- No consumable slot free. Nick's rule: nothing is produced.
        if card.added_to_deck then card:remove_from_deck() end
        card:remove()
        return
    end
    return ref_emplace(self, card, location, stay_flipped)
end

----------------------------------------------------------------------
-- Price: OFF by default as of v1.3.0. Judgement costs its vanilla $3
-- (game.lua:553). Flipping cfg.reprice on restores the $7 override.
----------------------------------------------------------------------
local ref_set_cost = Card.set_cost

function Card:set_cost()
    if on() and cfg.reprice
       and self.config and self.config.center
       and self.config.center.key == 'c_judgement' then
        self.base_cost = cfg.judgement_cost
    end
    return ref_set_cost(self)
end

----------------------------------------------------------------------
-- Run start: Joker slots. Default 5 is vanilla, so this is a no-op
-- unless the config is raised deliberately.
----------------------------------------------------------------------
local ref_start_run = Game.start_run

function Game:start_run(args)
    ref_start_run(self, args)
    if not on() then return end

    if cfg.joker_slots and cfg.joker_slots > 5 then
        if G.GAME and G.GAME.starting_params then
            G.GAME.starting_params.joker_slots = cfg.joker_slots
        end
        -- Only raise the floor. Anything that added slots during a loaded run
        -- (Negative Jokers, Antimatter) keeps them.
        if G.jokers and G.jokers.config
           and G.jokers.config.card_limit < cfg.joker_slots then
            G.jokers.config.card_limit = cfg.joker_slots
        end
    end
end

----------------------------------------------------------------------
-- FIX 1: runaway particles.
--
-- Card:start_materialize assigns self.children.particles, then queues an
-- event that stops emission by reading self.children.particles at FIRE time
-- (card.lua:2197 and the 'after' event below it). Calling it twice replaces
-- the reference, so the first emitter is orphaned: nothing ever sets its max
-- to 0 and it keeps firing forever.
--
-- Vanilla never doubles up, because a Joker is not consumeable and so
-- create_card's auto-materialize branch does not run for it. Our Judgement IS
-- consumeable, so create_card materializes it AND the call site materializes
-- it again. Riff-raff is the visible case. Kill any live emitter first.
----------------------------------------------------------------------
local ref_start_materialize = Card.start_materialize

function Card:start_materialize(dissolve_colours, silent, timefac)
    local p = self.children and self.children.particles
    if p then
        p.max = 0
        if p.remove then p:remove() end
        self.children.particles = nil
    end
    return ref_start_materialize(self, dissolve_colours, silent, timefac)
end

----------------------------------------------------------------------
-- FIX 2: Riff-raff gated on the wrong resource.
--
-- card.lua:2529 guards on Joker room and card.lua:2530 sizes the batch from
-- Joker room, but under this mod the cards land in consumables. Confirmed in
-- testing: full Joker slots produced nothing even with consumables empty, and
-- one free Joker slot produced exactly one Judgement.
--
-- Both lines read G.jokers.config.card_limit synchronously, so lending the
-- Joker area exactly as much headroom as consumables actually have makes the
-- vanilla arithmetic land on the right answer. jokers_to_create is captured
-- as an upvalue before the queued event runs, so restoring afterwards is safe.
----------------------------------------------------------------------
local ref_calculate_joker = Card.calculate_joker

function Card:calculate_joker(context)
    if on() and self.ability and self.ability.name == 'Riff-raff' and G.jokers then
        local jk     = G.jokers
        local saved  = jk.config.card_limit
        jk.config.card_limit = #jk.cards + (G.GAME.joker_buffer or 0) + consumable_room()
        local ok, ret = pcall(ref_calculate_joker, self, context)
        jk.config.card_limit = saved
        if not ok then error(ret, 0) end
        return ret
    end
    return ref_calculate_joker(self, context)
end

----------------------------------------------------------------------
-- FIX 3: Top-up Tag, same wrong resource.
--
-- tag.lua:137 has the identical Joker-room guard, but it sits inside the
-- Tag:yep callback, which is deferred by 0.4s through E_MANAGER. Lending
-- headroom the way Riff-raff does would be restored long before it runs, so
-- the branch is reimplemented here instead, faithful to tag.lua:133-148 with
-- the one guard swapped to consumable room.
----------------------------------------------------------------------
local ref_tag_apply = Tag.apply_to_run

function Tag:apply_to_run(_context)
    if on() and self.name == 'Top-up Tag'
       and _context and _context.type == 'immediate' and not self.triggered then
        local lock = self.ID
        G.CONTROLLER.locks[lock] = true
        self:yep('+', G.C.PURPLE, function()
            for _ = 1, (self.config.spawn_jokers or 2) do
                if consumable_room() > 0 then
                    local card = create_card('Joker', G.jokers, nil, 0, nil, nil, nil, 'top')
                    card:add_to_deck()
                    G.jokers:emplace(card)      -- the emplace wrapper redirects
                end
            end
            G.CONTROLLER.locks[lock] = nil
            return true
        end)
        self.triggered = true
        return true
    end
    return ref_tag_apply(self, _context)
end

----------------------------------------------------------------------
-- FIX 4: The Soul and Wraith gated on Joker room. Found by reading, not
-- reported.
--
-- Card:can_use_consumeable (card.lua:1557) refuses Judgement, The Soul and
-- Wraith while Joker slots are full. Correct for Judgement, which still makes
-- a Joker. Wrong for the other two now, since they hand over a Judgement and
-- need consumable room instead. Without this you cannot use a Wraith with a
-- full board even though it would only have given you a card.
----------------------------------------------------------------------
local GRANTS_JUDGEMENT = { c_soul = true, c_wraith = true }

local ref_can_use = Card.can_use_consumeable

function Card:can_use_consumeable(any_state, skip_check)
    if on() and self.config and self.config.center
       and GRANTS_JUDGEMENT[self.config.center.key]
       and not (self.config.center.key == 'c_soul' and not cfg.convert_soul)
    then
        return consumable_room() > 0 or self.area == G.consumeables
    end
    return ref_can_use(self, any_state, skip_check)
end

----------------------------------------------------------------------
-- Ban Riff-raff.
--
-- Riff-raff is the ONLY Joker in the game that creates Jokers from a trigger
-- (card.lua:2529, fired from state_events.lua:336 on setting_blind). Every
-- other Joker-creating effect is a consumable or a tag, and those are handled
-- above. So this one ban covers the whole class.
--
-- It is banned by DEFAULT because as of v1.4.0 it does not work under this mod
-- and the cause is not understood. Tested live on 23 Aug 2026: six Jokers on
-- board, two free consumable slots, and it produced nothing. The arithmetic in
-- FIX 2 was traced against source and should have created two Judgements, so
-- the wrapper is not executing rather than computing wrong. Until that is
-- explained, Riff-raff is a Joker that occupies a slot and does nothing, which
-- is worse for the run than never seeing it.
--
-- Key verified at game.lua:438: j_riff_raff, rarity 1, cost 6.
--
-- get_current_pool returns G.ARGS.TEMP_POOL, a scratch table that is emptied
-- at the top of every call (common_events.lua:1965), and it holds string keys
-- (common_events.lua:2031). Writing 'UNAVAILABLE' into it is what vanilla does
-- itself, and create_card resamples on that value, so this cannot corrupt
-- G.P_JOKER_RARITY_POOLS.
----------------------------------------------------------------------
local RIFFRAFF_KEY = 'j_riff_raff'

local ref_get_current_pool = get_current_pool

function get_current_pool(_type, _rarity, _legendary, _append)
    local pool, key = ref_get_current_pool(_type, _rarity, _legendary, _append)
    if on() and cfg.ban_riffraff and pool then
        for i = 1, #pool do
            if pool[i] == RIFFRAFF_KEY then pool[i] = 'UNAVAILABLE' end
        end
    end
    return pool, key
end

----------------------------------------------------------------------
-- Config tab.
----------------------------------------------------------------------
THIS_MOD.config_tab = function()
    return {
        n = G.UIT.ROOT,
        config = { align = 'cm', padding = 0.05, colour = G.C.CLEAR },
        nodes = {
            create_toggle({
                label = 'Enable JudgementRun',
                ref_table = cfg, ref_value = 'enabled',
            }),
            create_toggle({
                label = 'Price Judgement at what it grants',
                ref_table = cfg, ref_value = 'reprice',
            }),
            create_toggle({
                label = 'The Soul also gives a Judgement',
                ref_table = cfg, ref_value = 'convert_soul',
            }),
            create_toggle({
                label = 'Ban Riff-raff (does nothing under this mod)',
                ref_table = cfg, ref_value = 'ban_riffraff',
            }),
        }
    }
end
