# Master Application Specification: Project Roshambo

## 1. Executive Summary
**Project Name:** Roshambo  
**Platform:** Progressive Web App (PWA)  
**Framework:** React / Antigravity (Google)  
**Core Concept:** A patented, massively multiplayer social-psychology game. Players compete against the "World Throw"—the aggregate majority choice of the global player base—to earn exponential rewards through a "Stake or Bank" mechanic.

---

## 2. Core Game Mechanics

### 2.1 The World Throw (W)
The **World Throw** is the move ($R, P,$ or $S$) that receives the plurality of votes in a single synchronous round. 

### 2.2 Win/Loss/Safe Conditions
The player's choice (**P**) is compared against the World Throw (**W**):

| Condition | Result | Impact on Stake & Streak |
| :--- | :--- | :--- |
| **P defeats W** | **WIN** | Points tripled ($3^n$); Streak increments (+1). |
| **W defeats P** | **SAFE** | Stake and Streak are preserved. Player remains at current status. |
| **P matches W** | **LOSS** | **Stake is forfeited**; Streak resets to 0. |

### 2.3 Staking & Sideline Strategy
* **Exponential Growth:** Winnings follow a $3^n$ progression (e.g., 1, 3, 9, 27, 81...).
* **Voluntary Entry:** Players are not required to play consecutive rounds. A player can hold a stake/streak and "sit on the sidelines" to observe trends before committing to their next move.
* **Banking:** Between rounds, players can choose to **Bank** (save points to Lifetime Total and reset streak) or **Stake** (risk points in a future round).
* **Safe State Exit:** If a round results in a "Safe" outcome, the player is prompted to either Un-stake/Bank or continue their streak in a later round.

---

## 3. Technical Architecture (Antigravity/React)

### 3.1 PWA Requirements
* **WebSockets:** Real-time bi-directional communication for round timers, player counts, and the "Reveal" broadcast.
* **Persistence:** OAuth-based accounts to sync Lifetime Points and Inventory across devices.
* **Data Thrift Mode:** A user-toggled setting to disable animations and reduce WebSocket frequency to save data.

### 3.2 Round Lifecycle
1. **Lobby:** Waiting for minimum player threshold.
2. **Active:** A hard countdown timer (e.g., 30s) begins.
3. **Extension:** If a 3-way tie occurs, 10s "Overtime" increments are added until a majority emerges.
4. **Reveal:** Result broadcast; animations trigger; 5-second "Bank or Stake" decision window opens.

---

## 4. UI/UX & Data Modules

### 4.1 The "Tape" (Historical Data)
* **Default View:** Last 5 World Throws.
* **Power User View:** Percentage distribution for each past round (e.g., Rock 45%, Paper 30%, Scissors 25%) to help players spot "The Herd Mind" trends.

### 4.2 The Arena & Animation
* **Character Proxy:** Animated characters (Rive/Lottie) play specific Win, Loss, or Safe animations based on the server's broadcast.
* **The Store:** A marketplace where banked points are traded for skins, new characters, and visual/audio upgrades.

---

## 5. Data Schema (JSON)

### Player Object
```json
{
  "uid": "user_123",
  "lifetime_points": 1500,
  "current_stake": 27,
  "current_streak": 3,
  "inventory": ["skin_neon_01", "char_viking_01"],
  "active_skin": "skin_neon_01"
}

### Round Object
```json
{
  "round_id": "uuid-9876",
  "world_throw": "Rock",
  "distribution": { "R": 500, "P": 250, "S": 250 },
  "total_players": 1000,
  "timestamp": "2026-01-04T12:00:00Z"
}