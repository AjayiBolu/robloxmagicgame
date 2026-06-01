# PRD: Battle UI Overhaul + Cutscene System

## Problem Statement

The current battle board is a set of semi-transparent floating GUI panels layered over the live Roblox 3D world. During a match, the baseplate, player character models, and the surrounding environment are all visible through the transparent background. This breaks immersion — the game is a card game, so the 3D world adds no value and distracts from the cards and board. The hand is displayed as a flat horizontal scrolling strip, which feels mechanical rather than like holding a real hand of cards. There is also no cinematic feedback when significant moments occur (cards played, match won/lost), making the experience feel flat.

## Solution

Replace the transparent overlay approach with a fully opaque, MTG Arena-inspired battle board that completely covers the screen during a match. The board is split between the two players, each owning their own half with customizable cosmetics. Card hands are displayed as a fan at the bottom edge. Cinematic cutscenes play at key moments (card played, win/loss, card intro), triggered globally for both players but experienced and controlled independently per player.

## User Stories

1. As a player entering a match, I want the Roblox world to be completely hidden so that I can focus entirely on the card game board.
2. As a player, I want to see a clear visual split between my side of the board and my opponent's side so that I always know which zone belongs to whom.
3. As a player, I want my life total displayed as a circle near the center dividing line of the board so that I can monitor my health at a glance without looking away from the action.
4. As a player, I want my opponent's life total displayed symmetrically on their side of the center line so that I can track both life totals in one area.
5. As a player, I want my username pinned to the bottom-left of the screen and my opponent's username pinned to the top-right so that I always know who is who.
6. As a player, I want my current mana and max mana displayed near my life circle at the center so that I can plan plays without searching the screen.
7. As a player, I want my hand to display as a fan of cards arcing upward from the bottom edge so that the hand feels physical and familiar.
8. As a player, I want to hover over a hand card to lift and enlarge it so that I can read it clearly before deciding to play it.
9. As a player, I want cards I can afford to be visually highlighted and unaffordable cards to appear dimmed so that I can immediately see my legal plays.
10. As a player, I want a visible deck pile on the right side of my half showing a card-back stack and a remaining count so that I know how many cards I have left.
11. As a player, I want a visible graveyard zone on the right side of my half showing the top card and a count so that I can track discarded cards.
12. As a player, I want to click my graveyard to open an inspection panel listing all cards in it so that I can review what has been destroyed or discarded.
13. As a player, I want to see my opponent's deck count and graveyard (top card + count) on the right side of their half so that I can read their board state fully.
14. As a player, I want the current phase and whose turn it is displayed in a banner at the top center so that I always know what actions are legal right now.
15. As a player, I want an End Phase button near the center divider on my side so that I can advance through phases without reaching to the edge of the screen.
16. As a player, I want a Forfeit button at the top-right corner so that I can concede at any time.
17. As a player, I want my battlefield zone to be visually distinct from my opponent's zone (tinted colors, labeled) so that creature placement is always unambiguous.
18. As a player, I want creature cards on the battlefield to show their power/toughness badge, tapped/attacking status, and keyword strip so that combat state is readable at a glance.
19. As a player, I want to customize the cosmetic appearance of my half of the board (background color, pattern, border glow) using unlockable skins so that my board feels personal.
20. As an opponent, I want to see my opponent's board skin on their half of the field so that the match feels like two distinct players facing each other.
21. As a player who finds opponent board skins distracting, I want a setting to disable custom boards and show the default skin for both halves so that I can reduce visual noise.
22. As a player watching an impactful card be played, I want a 3D cinematic cutscene to play so that key moments feel dramatic and rewarding.
23. As a player, I want cutscenes to play globally — meaning both I and my opponent see the cutscene simultaneously — so that the dramatic moment is shared.
24. As a player, I want to press a Skip button during any cutscene to dismiss it immediately for myself without affecting my opponent's experience.
25. As a player, I want a settings panel where I can disable cutscenes entirely so that I can play without interruptions if I prefer fast games.
26. As a player, I want a settings panel where I can control cutscene frequency (all cards / rare cards only / legendary cards only) so that I can tune how often cinematics interrupt gameplay.
27. As a player, I want cutscenes to be purely cosmetic — the match state advances normally underneath — so that skipping or watching never delays the game.
28. As a player, I want a card intro cutscene to play the first time I play a card that has one so that I can appreciate the anime character being summoned.
29. As a player, I want a win cinematic to play when I defeat my opponent so that victory feels satisfying and earned.
30. As a player, I want a loss cinematic to play when my life total reaches zero so that even defeat has weight and presentation.
31. As a player rejoining a match in progress, I want the board to correctly reflect the current game state without needing to take an action first so that reconnection is seamless.

## Implementation Decisions

### Board Architecture

- The root ScreenGui frame is fully opaque (`BackgroundTransparency = 0`) during a match, completely covering the Roblox 3D world. No camera manipulation is needed.
- The board is divided horizontally at the vertical midpoint. The top half belongs to the opponent; the bottom half belongs to the local player.
- Each half renders its `boardSkin` independently. A `boardSkin` is a data table with fields for background color, accent color, border glow color, and optionally a pattern enum. Initially one default skin exists; the structure is built data-driven so unlockable skins can be added without touching render logic.
- A player setting `showOpponentSkin: boolean` (default `true`) controls whether the opponent's half renders their skin or the default. This is client-local and never sent to the server.

### Layout Zones (top to bottom)

```
┌───────────────────────────────────────────────────┐  ← screen top
│  [Phase Banner — center]         [Forfeit — right] │
│  opponent name                             top-right│
│                                                    │
│  ── OPPONENT HALF (top 50%) ──────────────────────│
│  │ Opp Battlefield                    │Opp Deck   ││
│  │                                    │Opp GY     ││
│  ──────── center divider ─────────────────────────│
│  [Opp Life Circle]   [My Life Circle + Mana]       │
│  [End Phase btn]                                   │
│  ── MY HALF (bottom 50%) ─────────────────────────│
│  │ My Battlefield                     │My Deck    ││
│  │                                    │My GY      ││
│  my name  bottom-left                             │
│  ── FAN HAND ──────────────────────────────────────│
└───────────────────────────────────────────────────┘  ← screen bottom
```

- Life circles for both players sit straddling the center divider line (opponent's circle just above, mine just below).
- Deck and graveyard zones are stacked vertically on the right side of each half.
- Clicking a graveyard zone opens a modal inspection panel (scrollable card list).

### Fan Hand

- Cards in hand are positioned along a shallow arc (`math.sin` offset for Y, slight rotation per card) centered horizontally at the bottom of the screen.
- Hovering a card tweens it upward (~30px) and scales it to 1.15x.
- Cards the player cannot afford or that are not playable in the current phase render at reduced opacity with no hover interaction.
- The hand re-lays-out whenever `BattleUI.update` is called (card count changes).

### Cutscene System

- A new remote `TriggerCutscene` (server → client, `FireAllClients` scoped to match participants) carries: `{ cardId, cutsceneType, actorKey }` where `cutsceneType` is `"cardPlay" | "cardIntro" | "win" | "loss"`.
- The server fires `TriggerCutscene` after resolving the action and broadcasting the updated `MatchStateUpdate` — state is always delivered first, cutscene is always after.
- The client-side `CutscenePlayer` module receives the event, checks the player's local cutscene settings, and either plays or silently drops it.
- During playback: board fades to black (alpha tween), cutscene runs in a `ViewportFrame` (for card intros) or via camera hijack (for win/loss), then fades back to the board.
- A Skip button (`ZIndex` above the cutscene frame) is always visible during playback. Pressing it immediately cancels the tween and restores the board for that player only. No server communication on skip.
- Cutscene settings shape: `{ enabled: boolean, frequency: "all" | "rare" | "legendary" }`. Stored locally for now (module-level table); wired to DataStore in a later pass.

### Board Skin System

- `BoardSkinRegistry` (shared module, read-only) maps `skinId → { bgColor, accentColor, glowColor, patternId }`.
- Default skin `"default"` is always available. Additional skins are unlocked via the microtransaction system (out of scope here — `BoardSkinRegistry` just needs to be queryable by skin ID).
- Each player's equipped `skinId` is sent as part of the `MatchFound` payload so both clients can render the opponent's skin immediately on match start.
- If `showOpponentSkin` is `false`, the opponent's half always renders `"default"` regardless of what the server sent.

### Modules Changed

- `BattleUI` — full rewrite of `open()`, `update()`, and hand rendering. New helpers: `buildFanHand()`, `buildDeckZone()`, `buildGraveyardZone()`, `buildBoardBackground()`.
- `MatchClient` — pass `boardSkin` from `MatchFound` data into `BattleUI.open()`.
- `MatchService` — include both players' `equippedSkinId` in the `MatchFound` fire payload.
- New module: `CutscenePlayer` (client) — owns cutscene playback, settings, and skip logic.
- New module: `BoardSkinRegistry` (shared) — skin data table.
- `RemoteSetup` — add `TriggerCutscene` RemoteEvent to MatchEvents folder.

## Testing Decisions

Good tests verify external behavior, not internals. For this feature that means: given a game snapshot, the correct elements are visible/hidden/styled; given a `TriggerCutscene` event with settings disabled, no cutscene frame appears; given a skin setting, the correct colors render.

- `BattleUI.update(snapshot)` → verify life labels, mana text, empty-zone hints, and hand card count match snapshot values. Prior art: existing snapshot broadcast in `MatchService`.
- Fan hand layout → verify that with N cards, N card frames exist in the hand container and each has a distinct `Position.Y` offset (arc shape). No need to test pixel values — just that offsets differ.
- Graveyard inspection → verify clicking the graveyard zone opens a panel containing the correct number of card entries from the snapshot's graveyard array.
- `CutscenePlayer` with `enabled = false` → fire `TriggerCutscene`, verify no cutscene frame is created in the ScreenGui.
- `CutscenePlayer` skip → start a cutscene, fire skip, verify the cutscene frame is destroyed and the board frame is visible again.
- Board skin → render a half with skin `"default"` vs a custom skin, verify `BackgroundColor3` differs between the two.

## Out of Scope

- Microtransaction integration (purchasing board skins) — `BoardSkinRegistry` is built data-driven but the store/unlock flow is a separate feature.
- DataStore persistence for cutscene settings and equipped skin — local state only for this pass.
- `CardEffectResolver` and `CombatResolver` (Phase 2 game logic hooks already stubbed in `MatchService`).
- Matchmaking improvements (MMR, ranked queue, timeout handling).
- `ViewportFrame` 3D character models for card intros — `CutscenePlayer` stubs the `"cardIntro"` type with a placeholder frame; full 3D implementation is a follow-up once character rigs exist.
- Mobile/tablet layout adjustments.

## Further Notes

- The cutscene system is designed so that adding a new cutscene type requires only: (1) a new `cutsceneType` string, (2) a handler branch in `CutscenePlayer`. No server changes needed beyond firing the existing `TriggerCutscene` remote with the new type.
- Board skin IDs are intentionally opaque strings (not enums) so new skins can be added to `BoardSkinRegistry` without any other code change.
- The fan hand arc uses screen-space math (`UDim2` offsets), not 3D — no `ViewportFrame` needed for the hand.
- Tapped creatures on the battlefield use a `Rotation` property offset (already implemented in current `BattleUI`) — this is preserved in the rewrite.
