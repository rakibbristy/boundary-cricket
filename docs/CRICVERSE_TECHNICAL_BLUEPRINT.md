# CRICVERSE Technical Blueprint
**Project:** CRICVERSE — Your World, Your Cricket.  
**Status:** Design baseline before gameplay redevelopment  
**Reference:** Publicly observable features and gameplay of World Cricket Championship 3 (WCC3). This is an original implementation plan, not a reverse-engineering claim.

---

## 1. Purpose and boundaries

The target is a polished 3D mobile cricket game with the depth and match flow expected from a modern cricket title. WCC3 is a product reference for feature coverage and feel only.

We do **not** have WCC3 source code, internal AI, proprietary animation graphs, original player rigs, or engine project. Public store descriptions, official videos, and observed gameplay can establish visible features; the internal mechanisms below are engineering proposals for CRICVERSE, not claims about WCC3 internals.

All code, models, textures, stadiums, UI, sounds, names, and animations used in CRICVERSE must be original or have a verified licence that permits the intended use. Never copy WCC3 assets or code.

## 2. Publicly observable reference features

Public WCC3 materials describe or show:
- Batting based on timing, footwork, shot choice and placement, with a broad range of ground and lofted shots.
- Bowling with pace, swing, spin, line/length and special deliveries.
- Running between wickets, sprinting and diving.
- Fielding actions including catches, dives/stops, pickups and throws/direct hits.
- Motion-captured player actions, multiple camera/control options, stadium presentation and dynamic opposition AI.
- Career progression, player skills/upgrades and multiple match formats/modes.

These are feature-level observations only. They do not reveal WCC3's exact equations, source architecture, AI decision trees, or animation implementation.

## 3. Current CRICVERSE baseline — known problems to replace

The previously reviewed prototype is a proof of concept, not a WCC3-level game:
- Ball flight is manually integrated with a simple gravity value and a limited bounce condition.
- Shot outcome is selected from timing plus random direction/velocity; there is no reliable physical bat/ball contact system.
- Batting is largely a bat-blade tween rather than a full-body animation sequence.
- Running is a straight timed movement with score added at completion; there is no proper striker/non-striker exchange, turn, dive, run-out or throw resolution.
- The bowling AI uses random outcomes rather than reading delivery line, length, batter stance and shot opportunity.
- Fielding uses only a small fixed group of fielders. The nearest player chases the ball's current position; there is no robust landing prediction, team backup, relay, pickup/throw chain or return-to-position behaviour.
- Stadium and presentation are largely primitive geometry and basic HUD controls.
- A single generic GLB player model was temporarily wired to batter, bowler and fielder roles. Its in-engine appearance, scale, orientation and animation compatibility have not been validated. It must not be treated as an approved final cricket character asset.

**Decision:** Do not add more features on top of these foundations. Rebuild the match simulation in layers and validate each layer before expanding scope.

## 4. Target match simulation

### 4.1 Delivery state machine

A delivery must progress through explicit states:

1. SETUP — choose bowler, batter, field, over/ball and match context.
2. BOWLER_RUNUP — bowler moves through a timed run-up animation.
3. RELEASE — release point, speed, direction, spin and seam parameters are fixed.
4. FLIGHT_PRE_BOUNCE — continuous ball trajectory with gravity and aerodynamic effects.
5. PITCH_CONTACT — detect a single physical pitch contact when applicable.
6. FLIGHT_POST_BOUNCE — continue trajectory with bounce response and spin/seam deviation.
7. BATTER_CONTACT_WINDOW — evaluate bat swing, bat pose, timing and collision.
8. SHOT_FLIGHT_OR_MISS — ball follows post-contact physics, or continues past the batter.
9. FIELDING_RESOLUTION — catch, stop, pickup, boundary, overthrow or run-out logic.
10. DEAD_BALL — settle the result, update score/wicket/over and prepare next delivery.

Transitions must be driven by simulation events, not unrelated timers or random state changes.

### 4.2 Ball physics

Use one authoritative ball simulation. Suggested model:
- Position and velocity in world space, updated using a fixed physics timestep.
- Gravity and configurable air drag.
- Pitch collision with restitution, friction and spin-dependent lateral response.
- Bat collision using a defined bat collision shape and swing velocity.
- Ground friction and rolling deceleration after landing.
- Collision tests for stumps, boundary volume and relevant player/catch zones.
- Numerical safeguards: clamp extreme velocities, prevent repeated ground penetration, and use swept collision/raycast checks for fast-moving balls.

The ball must not bounce repeatedly because of frame timing. A pitch-contact event should occur once per delivery unless a deliberate second surface collision is physically valid.

### 4.3 Batting system

Separate input, animation and shot resolution.

**Input phase**
- Read shot direction, shot type, footwork intent and timing input.
- Support configurable controls and a clear input buffer.
- Determine whether the batter is balanced, moving, late or early.

**Decision phase**
- Evaluate delivery line, length, speed, bounce, batter stance, handedness, selected shot and player attributes.
- Select a valid shot family and intended contact region.
- Reject impossible shots or reduce their quality rather than producing arbitrary outcomes.

**Contact phase**
- Calculate bat-face orientation and swing velocity at the contact frame.
- Evaluate timing error, contact point, bat-ball relative velocity and shot intent.
- Derive launch direction and speed from contact quality and player skill.
- Allow edges, mistimed hits, defensive contacts and misses as meaningful outcomes.

**Shot families for staged implementation**
1. Defensive block and leave.
2. Front-foot drive and straight drive.
3. On-drive, off-drive and cover drive.
4. Back-foot cut and late cut.
5. Pull and hook.
6. Flick and leg glance.
7. Sweep and slog-sweep.
8. Lofted versions and advanced/reverse shots.

Start with reliable core shots. Add advanced shots only after timing, contact and ball trajectory work consistently.

### 4.4 Bowling system

Bowling should be parameter-driven, not random:
- Run-up length, speed and release animation.
- Release point, pace, line, length and target.
- Swing/seam/spin as controlled physical parameters.
- Delivery types such as stock ball, yorker, bouncer, slower ball, cutter and spin variations.
- Bowler attributes affect control, pace, movement and fatigue.
- Accuracy has a skill-based spread, but every delivery remains explainable by its chosen parameters.

The ball's actual path must match the selected line and length closely enough for a player to learn and anticipate it.

### 4.5 Running between wickets

Use a wicket-to-wicket run state machine:
- READY, CALL, ACCELERATE, RUNNING, TURN, RETURN, SLIDE_DIVE, SAFE, RUN_OUT.
- Track both batters and their crease positions.
- A run is scored only when both batters complete the required ends safely.
- Add calling/response, hesitation, cancel/return decisions and collision avoidance.
- Run-out is resolved from ball arrival, fielder release/throw, stump contact and batter ground position.
- Sprinting and diving consume stamina and must have a meaningful timing trade-off.

### 4.6 Fielding team AI

Fielding is a team problem, not simply “nearest fielder follows ball”.

**Ball prediction**
- Predict landing point and arrival time from ball position, velocity and physics.
- Recalculate prediction as the ball changes direction or bounces.
- Estimate catchability, ground-stop opportunity and boundary risk.

**Role assignment**
- Select a primary interceptor.
- Assign a backup/relay fielder.
- Assign boundary protection and cover roles.
- Avoid sending multiple fielders to the same point unless a deliberate backup is required.

**Fielder state machine**
POSITIONED → READ_BALL → INTERCEPT → SPRINT → CATCH_OR_DIVE / GROUND_STOP → PICKUP → THROW → RELAY_OR_BACKUP → RETURN_TO_POSITION

**Fielding actions**
- Catch attempt uses predicted ball path, fielder reach, reaction delay and catching skill.
- Ground stop uses body/hand reach and ball speed.
- Pickup requires the player to reach and collect the ball before throwing.
- Throw uses direction, power, release animation and throwing skill.
- Backup players cover likely overthrow paths.
- After the play, fielders recover and return to their tactical positions.

The AI should be deterministic enough to debug. Randomness may vary reaction and execution within skill-based ranges, but should never replace the underlying decision logic.

### 4.7 Wicketkeeper

The wicketkeeper is a distinct role with:
- Stance and readiness based on delivery type.
- Lateral movement and take position.
- Catch, gather, stumping and run-out interactions.
- Ball collection and return to bowler.
- Dedicated animations and reach limits.

## 5. Player, animation and asset pipeline

### 5.1 Character requirements

Do not use one unvalidated generic model as the final solution for every role. Each approved character must have:
- Correct humanoid skeleton and consistent bone naming/retargeting.
- Cricket clothing and role-appropriate equipment.
- Correct scale, forward axis, origin and ground contact.
- Separate materials/colour variants that remain readable on mobile.
- LODs and sensible polygon/texture budgets.
- Verified licence and source recorded in the repository.

Roles may share a compatible base skeleton, but batter, bowler, fielder and wicketkeeper need role-specific equipment and animation coverage.

### 5.2 Animation state system

Animation is driven by gameplay state and blended by movement speed/direction.

**Batter:** idle, ready stance, backlift, front-foot step, back-foot step, defensive shot, drive, pull, sweep, lofted shot, follow-through, run start, sprint, turn, dive, recover.

**Bowler:** idle, run-up, gather, bound, delivery stride, release, follow-through, walk-back.

**Fielder:** ready stance, reaction, sprint, side-step, jump, catch, dive left/right, ground stop, pickup, overarm throw, underarm throw, relay, recover, return.

**Keeper:** crouch, lateral shuffle, take, catch, gather, stumping, throw.

Animation events should mark important frames such as ball release and bat contact. Gameplay timing must not depend solely on a visual animation finishing.

### 5.3 Asset acceptance

Before an asset is integrated:
1. Verify licence and redistribution rights.
2. Inspect the model in the target Godot version.
3. Check scale, orientation, skeleton, materials and textures.
4. Test animation import and retargeting.
5. Test on a representative Android device.
6. Record source, licence, modifications and file hash in an asset register.

## 6. Game architecture (Godot proposal)

Keep responsibilities separated:

- MatchManager — innings, overs, score, wickets, target, match phase and rules.
- DeliveryController — delivery setup and state transitions.
- BallSimulation — authoritative ball physics and collision events.
- BattingController — input, stance, footwork, shot selection and contact.
- BowlingController — run-up, release and delivery parameters.
- RunningBetweenWickets — batter movement, calls, crease checks and run-outs.
- FieldingCoordinator — ball prediction, role assignment and team tactics.
- FielderController — individual movement, catch, stop, pickup and throw.
- WicketkeeperController — keeper-specific decisions and actions.
- PlayerAttributes — skill values, handedness, stamina and role data.
- AnimationController — state-to-animation mapping and event markers.
- CameraDirector — batting, bowling, broadcast, fielding and replay cameras.
- MatchPresentation — scoreboard, commentary, effects, sound and UI.
- InputSettings — control layout, sensitivity and accessibility options.

Use signals/events for important simulation outcomes (release, bounce, contact, catch, boundary, completed run, wicket). Avoid having every player script directly modify the scoreboard.

## 7. Camera, sound and presentation

Required camera modes:
- Broadcast overview for normal play.
- Bowler/run-up and release view.
- Batter-focused view with clear sight of the ball.
- Ball-follow/fielding view for long shots.
- Brief replay camera for boundaries, wickets and close run-outs.

Presentation priorities:
- Stable frame pacing before visual effects.
- Clear ball visibility against pitch, sky and stands.
- Readable score/over/wicket display.
- Responsive control feedback and subtle hit/catch/appeal effects.
- Original crowd, bat impact, pitch, stump and ambience sounds.
- Camera transitions must not hide the ball during active play.

## 8. Mobile performance and controls

- Target stable performance on mid-range Android devices before adding expensive effects.
- Use LODs, baked lighting where appropriate, limited real-time shadows and pooled effects.
- Keep physics deterministic and lightweight.
- Support scalable UI for different aspect ratios and safe areas.
- Controls must be movable/resizable or offer clear presets.
- Separate shot selection from run/cancel controls; avoid accidental overlap.
- Provide sensitivity and camera options.
- Include a low-graphics mode.

## 9. Development order and quality gates

Do not build career mode, online multiplayer or a large stadium catalogue before the core match works.

### Gate 0 — project integrity
- Project opens without errors.
- Main scene loads on desktop and Android export.
- No missing assets or broken resource paths.
- One approved character asset displays correctly.

### Gate 1 — one delivery, no batting
- Bowler run-up and release.
- Ball travels on selected line/length.
- Exactly one expected pitch bounce.
- Ball can reach keeper/stumps reliably.
- Debug trajectory view available.

### Gate 2 — playable batting
- Batter stance and full-body shot animation.
- At least defensive, drive, pull and lofted shot.
- Contact timing changes the outcome.
- Ball direction comes from contact/shot intent, not a random left/right choice.
- Miss, edge, ground shot and aerial shot outcomes are possible.

### Gate 3 — running and scoring
- Two batters exchange ends.
- Runs count only after both complete the run.
- Turn, return, cancel and dive.
- Boundary and wicket rules.
- Run-out based on ball/stumps/crease timing.

### Gate 4 — complete fielding team
- Full fielding side with tactical positions.
- Predicted interception rather than chasing current ball position.
- Catch, dive, ground stop and pickup.
- Throw to keeper/stumps, backup and overthrow handling.
- Fielders recover and return to position.

### Gate 5 — one polished over
- One complete over can be played without broken states.
- Batting, bowling, fielding, running, wickets and boundaries work together.
- No repeated phantom bounce, frozen fielder, impossible run or score desync.
- Stable target-device frame rate.
- At least one short replay and broadcast camera.

**Only after Gate 5 passes** should we expand to full innings, more teams, tournaments, career progression and online features.

## 10. Mandatory test cases

| Test | Expected result |
|---|---|
| Yorker | Low delivery reaches batter; no unexplained extra bounce |
| Good-length ball | One pitch bounce at a plausible location |
| Defensive contact | Ball remains low with low launch speed |
| Timed drive | Direction and speed follow bat face and timing |
| Mistimed loft | Reduced control and catchable trajectory |
| Clean loft | High trajectory with plausible landing point |
| Edge | Deflection differs from clean contact |
| Ground shot | Ball rolls and slows; does not keep bouncing |
| Boundary | Four/six awarded according to boundary rule |
| Catch | Fielder predicts and reaches the catch point |
| Ground stop | Fielder stops, gathers and picks up the ball |
| Throw | Ball travels to intended end with plausible speed |
| Backup | Secondary fielder covers overthrow path |
| Completed run | Both batters safely reach opposite creases |
| Run-out | Wicket only if ball breaks wicket before batter is safe |
| Reset | Next delivery starts with all players in valid positions |

## 11. Definition of done for the first real prototype

A prototype is not accepted because it launches or contains 3D models. It is accepted only when a user can play a complete over and see:
- A bowler with a proper run-up and release.
- A ball with believable flight, bounce and rolling.
- A batter who can play several distinct shots with timing and footwork.
- Realistic outcomes from contact quality.
- Two batters who run, turn and can be run out.
- A full fielding team that predicts, intercepts, catches/stops, picks up and throws.
- A keeper who receives and attempts stumpings/run-outs.
- Clear score, wickets, overs and boundaries.
- Stable controls, camera and performance on Android.

**No claim of WCC3 equivalence should be made until these behaviours are demonstrated in a playable build.**
