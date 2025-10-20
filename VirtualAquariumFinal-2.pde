/**
 * Virtual Aquarium — intro + interactive sim (NO AUDIO)
 * Processing (Java mode)
 *
 * Controls:
 *  - Click bottom-right arrow to progress intro scenes.
 *  - Click top-right "crumb" to drop food; fish chase & eat.
 *  - Click top-left shark to toggle predator cursor (fish avoid it).
 *  - Click bottom-left "Restart" button to restart the game.
 *  - Click bottom-right toggle for Day/Night with bubbly transition.
 *  - Press ESC while in predator mode to exit predator mode instead of closing.
 */

// -------------------- MUSIC --------------------
import processing.sound.*;
SoundFile music;

// -------------------- SCENES --------------------
enum Scene { INTRO, INSTRUCTIONS, GAME }
Scene scene = Scene.INTRO;

// Restart button bounds (computed each frame in drawSettings)
float restartX, restartY, restartW = 110, restartH = 36;

// -------------------- WORLD --------------------
int W = 960, H = 600;
PGraphics tankLayer;
ArrayList<Fish> fishes = new ArrayList<Fish>();
ArrayList<Food> foods  = new ArrayList<Food>();
ArrayList<Bubble> bubbles = new ArrayList<Bubble>();
ArrayList<Starfish> starfish = new ArrayList<Starfish>(); // starfish props

// hunger/shrink rules
final int HUNGER_DELAY_MS = 120000;   // 2 minutes before shrink begins
final int HUNGER_DURATION_MS = 60000; // then 1 minute until pop
final float MIN_SCALE = 0.22;

boolean predatorMode = false;

// UI
Icon arrowNext, crumbIcon, sharkIcon;
Toggle dayNightToggle;

boolean showHowTo = false;
boolean night = false;

// day/night bubbly transition
boolean bubbleTransition = false;
int bubbleTransitionStart = 0;
final int BUBBLE_TRANSITION_MS = 1300;

// -------------------- STORY --------------------

RectButton closeHowTo;

void restartGame() {
  fishes.clear();
  foods.clear();
  bubbles.clear();
  starfish.clear();           // clear starfish
  predatorMode = false;
  night = false;
  bubbleTransition = false;
  showHowTo = false;
  scene = Scene.INTRO;

  for (int i=0; i<20; i++)
    fishes.add(new Fish(new PVector(random(160, W-160), random(160, H-120))));
  spawnStarfish();            // (re)spawn starfish on restart
}

void settings(){ size(W, H); smooth(4); }

void setup() {
  music = new SoundFile(this, "baby-shark-122769.mp3");
  music.play();

  surface.setTitle("Virtual Aquarium");
  tankLayer = createGraphics(W, H);

  // UI
  arrowNext = new Icon(W-84, H-68, 56, "→");
  crumbIcon = new Icon(W-60, 28, 36, "•");
  sharkIcon = new Icon(32, 32, 36, "🦈");
  dayNightToggle = new Toggle(width - 120, height - 50, 60);

  closeHowTo = new RectButton(0, 0, 28, 28, "x");

  for (int i=0; i<20; i++)
    fishes.add(new Fish(new PVector(random(160, W-160), random(160, H-120))));

  spawnStarfish();            // initial starfish sprinkle
  renderTank();
}

void drawBabySharkAt(float x, float y) {
  pushMatrix();
  translate(x, y);
  noStroke();
  fill(170, 210, 235);
  ellipse(0, 0, 70, 48);               // body
  fill(240);
  arc(0, 6, 70, 48, -PI, 0);           // belly
  fill(160, 200, 230);
  triangle(-18, -16, 0, -40, 18, -16); // top fin
  triangle(34, 0, 58, -12, 58, 12);    // tail
  fill(0); ellipse(-10, -4, 8, 8);     // eye
  fill(255); ellipse(-9, -5, 3, 3);    // eye shine
  fill(255);                           // teeth
  triangle(-2, 8, 6, 8, 2, 14);
  triangle(6, 8, 14, 8, 10, 14);
  popMatrix();
}

// ----- Fancy icon drawings (visuals only) -----
void drawFeedButton(Icon b) {
  pushMatrix(); pushStyle();
  translate(b.x, b.y);

  // card
  noStroke();
  fill(255, 240);
  rectMode(CENTER);
  rect(0, 0, b.s+10, b.s+10, 12);

  // pellets — centered cluster
  fill(150, 110, 60);
  ellipse(-8, -1, 6, 6);
  ellipse( 0,  2, 6, 6);
  ellipse( 8, -1, 6, 6);

  popStyle(); popMatrix();
}

void drawSharkButton(Icon b) {
  pushMatrix(); pushStyle();
  translate(b.x, b.y);
  // card
  noStroke();
  fill(255, 240);
  rectMode(CENTER);
  rect(0, 0, b.s+10, b.s+10, 12);

  // tiny shark — visually centered via dx
  float dx = -2;  // nudge left to counter tail weight
  noStroke();
  fill(170, 210, 235);                 // body
  ellipse(dx + 0, 0, 28, 20);
  fill(240);
  arc(dx + 0, 3, 28, 20, -PI, 0);
  fill(160, 200, 230);
  triangle(dx - 8, -7, dx + 0, -16, dx + 8, -7);     // top fin
  triangle(dx + 12, 0, dx + 20, -5, dx + 20, 5);     // tail
  fill(0); ellipse(dx - 4, -2, 3.5, 3.5);            // eye
  fill(255); ellipse(dx - 3.5, -2.5, 1.5, 1.5);

  popStyle(); popMatrix();
}

// --- Top Icons Layout + Drawing Helpers ---

void layoutTopIcons() {
  float topMargin = 40;   // vertical space from top
  float sideMargin = 60;  // horizontal space from edges
  float yPos = topMargin + (sharkIcon.s + 10) / 2.0;

  // Shark icon (top-left)
  sharkIcon.x = sideMargin + sharkIcon.s / 2.0;
  sharkIcon.y = yPos;

  // Feed icon (top-right)
  crumbIcon.x = width - sideMargin - crumbIcon.s / 2.0;
  crumbIcon.y = yPos;
}

void drawTopIconsAndLabels() {
  drawSharkButton(sharkIcon);
  drawFeedButton(crumbIcon);

  // label color: soft dark in day, soft glow in night
  if (night) {
    fill(230, 235, 255, 210);   // light, slightly bluish for dark mode
  } else {
    fill(60, 70, 90, 190);      // darker gray-blue for light mode
  }

  textAlign(CENTER, TOP);
  textSize(14);
  text("Shark", sharkIcon.x, sharkIcon.y + sharkIcon.s / 2.0 + 8);
  text("Feed",  crumbIcon.x, crumbIcon.y + crumbIcon.s / 2.0 + 8);
}


void drawWaterGradient() {
  // vertical sky→deep gradient
  for (int y = 0; y < H; y++) {
    float t = map(y, 0, H, 0, 1);
    int c = lerpColor(color(190,230,255), color(150,205,240), t*0.6);
    stroke(c);
    line(0, y, W, y);
  }
}

void drawLightBeams() {
  // subtle angled beams near top (animated)
  noStroke();
  int base = 210;
  for (int i = 0; i < 4; i++) {
    float px = W*(0.15 + 0.2*i) + 40*sin((frameCount*0.01f)+(i*2.1));
    fill(255, 30); // translucent
    beginShape();
    vertex(px-80, -10);
    vertex(px+80, -10);
    fill(255, 0);
    vertex(px+180, 220);
    vertex(px-180, 220);
    endShape(CLOSE);
  }
}

void drawGlassVignette() {
  // very soft inner border to make the glass tank
  noFill();
  for (int i = 0; i < 40; i++) {
    stroke(255, 30 - i*0.6);
    rect(18+i*0.04, 18+i*0.04, W-36-i*0.08, H-36-i*0.08);
  }
}

void drawIntroTitleCard() {
  String title = "Virtual Aquarium";
  String sub   = "Click the arrow to begin";

  float cardW = 460, cardH = 120;
  float x = W*0.5f - cardW/2;
  float y = 48; // nice margin from top

  // shadow
  noStroke();
  fill(0, 35);
  rect(x+6, y+10, cardW, cardH, 20);

  // glassy card
  fill(255, 220);
  stroke(255, 200);
  rect(x, y, cardW, cardH, 20);

  // text
  fill(30, 180);
  textAlign(CENTER, CENTER);
  textSize(28);
  text(title, x+cardW/2, y+44);
  textSize(14);
  fill(30, 120);
  text(sub, x+cardW/2, y+84);
}
void drawNextPill() {
  float bx = W - 100, by = H - 64, bw = 70, bh = 44;
  // shadow
  noStroke(); fill(0, 35);
  rect(bx+4, by+6, bw, bh, 14);
  // pill
  fill(255, 240);
  rect(bx, by, bw, bh, 14);
  // arrow
  fill(40,140,240);
  textAlign(CENTER, CENTER);
  textSize(20);
  text("→", bx + bw/2, by + bh/2 + 1);
}

void draw() {
  background(220);

  if (bubbleTransition) drawBubbleTransition();

  switch(scene) {
    case INTRO:
      drawAquariumFrame();
      drawIntroTitleCard();
      drawNextPill();
      if (frameCount % 8 == 0) bubbles.add(new Bubble(new PVector(random(W*0.2, W*0.8), H-10)));
      break;

    case INSTRUCTIONS:
      drawAquariumFrame();
      if (showHowTo) drawHowToPopup(); 
      else scene = Scene.GAME;
      break;

    case GAME: {
      drawAquariumFrame();

      // --- top row icons ---
      layoutTopIcons();          // positions Shark + Feed
      drawTopIconsAndLabels();   // draws icons and text labels

      // --- bottom row ---
      drawRestartButton();
      dayNightToggle.draw(night);

      // shark cursor logic
      if (predatorMode && !showHowTo) {
        noCursor();
        drawBabySharkAt(mouseX, mouseY);
      } else {
        cursor(ARROW);
      }
      break;
    }
  }
}

// -------------------- INPUT --------------------
void mousePressed() {
  // intro → next (directly to instructions)
  if (scene == Scene.INTRO) {
    if (arrowNext.hit(mouseX, mouseY)) {
      scene = Scene.INSTRUCTIONS;
      showHowTo = true;
      return;
    }
  }

  // instructions: only close when X is clicked, then go to GAME
  if (scene == Scene.INSTRUCTIONS) {
    if (showHowTo && closeHowTo != null && closeHowTo.hit(mouseX, mouseY)) {
      showHowTo = false;
      scene = Scene.GAME;
    }
    return; // swallow clicks while the popup is shown
  }

  // game interactions
  if (scene == Scene.GAME) {
    if (crumbIcon.hit(mouseX, mouseY) && !showHowTo) { dropCrumbs(); return; }
    if (sharkIcon.hit(mouseX, mouseY) && !showHowTo) { predatorMode = !predatorMode; return; }
    if (dayNightToggle.hit(mouseX, mouseY)) { night = !night; startBubbleTransition(); return; }

    // Restart button (always available in GAME)
    if (mouseX > restartX && mouseX < restartX + restartW &&
        mouseY > restartY && mouseY < restartY + restartH) {
      restartGame();
      return;
    }
  }
}

void mouseDragged() { }
void mouseReleased() { }

void keyPressed() {
  if (key==ESC && predatorMode) { predatorMode = false; key = 0; }
  if (key=='r' || key=='R') restartGame();
}

// -------------------- STARFISH SUPPORT --------------------
// Creating a mix of small and fish-sized starfish on the sand
void spawnStarfish() {
  starfish.clear();
  int sandY = H - 90;

  int smallCount = 8;
  int bigCount   = 5;

  // small ones
  for (int i = 0; i < smallCount; i++) {
    float x = random(40, W - 40);
    float y = random(sandY + 12, H - 18);
    float r = random(10, 16);            // small radius
    starfish.add(new Starfish(new PVector(x, y), r, random(TWO_PI), false));
  }
  // big ones (roughly fish-sized)
  for (int i = 0; i < bigCount; i++) {
    float x = random(40, W - 40);
    float y = random(sandY + 16, H - 22);
    float r = random(22, 30);            // big radius ~ fish
    starfish.add(new Starfish(new PVector(x, y), r, random(TWO_PI), true));
  }
}

// -------------------- WORLD RENDER --------------------
void renderTank() {
  tankLayer.beginDraw();
  tankLayer.background(night? color(10,22,40) : color(190, 230, 255));

  // glass vignette
  for (int i=0; i<80; i++) {
    tankLayer.noFill();
    tankLayer.stroke(255, 50-i*0.6);
    tankLayer.rect(18+i*0.04, 18+i*0.04, W-36-i*0.08, H-36-i*0.08);
  }

  // sand
  int sandY = H-90;
  tankLayer.noStroke();
  tankLayer.fill(night? color(60,60,70) : color(235, 205, 140));
  tankLayer.rect(0, sandY, W, H-sandY);

  // plants
  for (int x=60; x<W; x+=160) drawPlant(tankLayer, x, sandY, night);

  tankLayer.endDraw();
}

void drawAquariumFrame() {
  // --- WATER + LIGHTS + PLANTS (drawn into tankLayer) ---
  tankLayer.beginDraw();
  tankLayer.background(0, 0);   // clear

  // vertical gradient (day vs night)
  for (int y = 0; y < H; y++) {
    float t = map(y, 0, H, 0, 1);
    int c = night
      ? lerpColor(color(10,22,40),  color(20,35,60),  t*0.7)
      : lerpColor(color(190,230,255), color(150,205,240), t*0.6);
    tankLayer.stroke(c);
    tankLayer.line(0, y, W, y);
  }

  // soft light beams near the surface (day only)
  if (!night) {
    tankLayer.noStroke();
    for (int i = 0; i < 4; i++) {
      float px = W*(0.15 + 0.2*i) + 40*sin((frameCount*0.01f)+(i*2.1f));
      tankLayer.fill(255, 30);
      tankLayer.beginShape();
      tankLayer.vertex(px-80, -10);
      tankLayer.vertex(px+80, -10);
      tankLayer.fill(255, 0);
      tankLayer.vertex(px+180, 220);
      tankLayer.vertex(px-180, 220);
      tankLayer.endShape(CLOSE);
    }
  }

  // sand
  int sandY = H - 90;
  tankLayer.noStroke();
  tankLayer.fill(night ? color(60,60,70) : color(235,205,140));
  tankLayer.rect(0, sandY, W, H - sandY);

  // plants
  for (int x = 60; x < W; x += 160) drawPlant(tankLayer, x, sandY, night);

  // STARFISH on top of sand/plants
  for (Starfish s : starfish) s.draw(tankLayer, night);

  // subtle glass vignette
  for (int i = 0; i < 40; i++) {
    tankLayer.noFill();
    tankLayer.stroke(255, 30 - i*0.6);
    tankLayer.rect(18+i*0.04, 18+i*0.04, W-36-i*0.08, H-36-i*0.08);
  }

  tankLayer.endDraw();
  image(tankLayer, 0, 0);

  // food
  for (int i=foods.size()-1; i>=0; i--) {
    Food f = foods.get(i);
    f.update(); f.draw();
    if (f.dead) foods.remove(i);
  }

  // fish
  for (int i=fishes.size()-1; i>=0; i--) {
    Fish f = fishes.get(i);
    f.update(); f.draw();
    if (f.popped) {
      // visual bubble only
      bubbles.add(new Bubble(f.pos.copy()));
      fishes.remove(i);
    }
  }

  // predator avoidance
  if (predatorMode && scene==Scene.GAME)
    for (Fish f : fishes) f.avoidPoint(new PVector(mouseX, mouseY), 150, 1.5);

  // bubbles visuals
  for (int i=bubbles.size()-1; i>=0; i--) {
    Bubble b = bubbles.get(i);
    b.update(); b.draw();
    if (b.dead) bubbles.remove(i);
  }

  // front glass shine
  noStroke();
  fill(255, night ? 12 : 28);
  rect(0, 0, W, 18);
  rect(0, H-18, W, 18);
  rect(0, 0, 18, H);
  rect(W-18, 0, 18, H);
}

// plants helper
void drawPlant(PGraphics g, float x, int baseY, boolean nightMode) {
  g.pushMatrix();
  g.translate(x, baseY);
  g.noStroke();
  int leaf = nightMode? color(60,130,110) : color(70,170,120);
  for (int i=0; i<8; i++) {
    float h = 60 + 18*i + 8*sin((frameCount+i)*0.03);
    g.fill(leaf, 130);
    g.ellipse(-12, -h, 20, 40);
    g.ellipse(+12, -h+8, 16, 36);
  }
  g.stroke(nightMode? color(40,100,85) : color(50,140,100));
  g.strokeWeight(4);
  g.noFill();
  for (int i=0; i<3; i++) g.bezier(0,0,-30,-40,40,-90,0,-130 - i*25);
  g.popMatrix();
}

void drawBabyFish(float cx, float cy, float scale, int bodyCol) {
  pushMatrix();
  translate(cx, cy);
  scale(scale);
  noStroke();
  fill(bodyCol);
  ellipse(0, 0, 40, 30); // body
  pushMatrix();
  translate(-24, 0);
  rotate(0.25 * sin(frameCount * 0.2));
  rect(-2, 0, 18, 12, 8);
  popMatrix();

  fill(255, 230);
  ellipse(6, -10, 10, 6);
  ellipse(10, 10, 10, 6);
  fill(0);
  ellipse(10, -2, 8, 8);
  fill(255);
  ellipse(11, -3, 3, 3);
  fill(255, 120, 140, 180);
  ellipse(6, 4, 8, 6);

  popMatrix();
}

// cute corner "How to Play" popup
void drawHowToPopup() {
  float margin = 20;
  float cardW = 300;
  float cardH = 260;
  float cardX = width - cardW - margin;
  float cardY = margin;

  // shadow
  noStroke();
  fill(0, 40);
  rect(cardX + 4, cardY + 6, cardW, cardH, 18);

  // body
  fill(255, 245);
  stroke(0, 50);
  strokeWeight(1.5);
  rect(cardX, cardY, cardW, cardH, 18);

  // header
  fill(90, 150, 255, 190);
  noStroke();
  rect(cardX, cardY, cardW, 36, 18, 18, 0, 0);

  // title
  fill(255);
  textAlign(LEFT, CENTER);
  textSize(16);
  text("🐠 How to Play", cardX + 16, cardY + 18);

  // close button
  closeHowTo.x = cardX + cardW - 34;
  closeHowTo.y = cardY + 7;
  closeHowTo.w = 26;
  closeHowTo.h = 22;
  closeHowTo.draw();

  // body text
  fill(20);
  textAlign(LEFT, TOP);
  textSize(13.5);
  float tx = cardX + 18;
  float ty = cardY + 48;
  text(
    "• Click the crumb in the top-right to feed your fish.\n\n" +
    "• Click the shark to introduce a predator to your aquarium.\n\n" +
    "• Fish begin shrinking after 2 minutes — feed them to keep them healthy!\n\n" +
    "• Click the restart button to restart the game; toggle night/day with the switch.\n\n" +
    "• Enjoy your cozy, bubbly aquarium world! 💧",
    tx, ty, cardW - 32, cardH - 60
  );
}

// bubbles transition visual
void startBubbleTransition() {
  bubbleTransition = true;
  bubbleTransitionStart = millis();
}

void drawBubbleTransition() {
  int t = millis() - bubbleTransitionStart;
  // spawn a bunch of bubbles as a screen wipe
  if (frameCount % 2 == 0 && t < BUBBLE_TRANSITION_MS) {
    for (int i=0; i<10; i++)
      bubbles.add(new Bubble(new PVector(random(W), H + random(20, 120))));
  }
  if (t > BUBBLE_TRANSITION_MS) bubbleTransition = false;
}

// drop food crumbs from top
void dropCrumbs() {
  for (int i=0; i<18; i++)
    foods.add(new Food(new PVector(random(50, W-50), -20-random(0, 200))));
}

// -------------------- CLASSES --------------------
class Fish {
  PVector pos, vel, acc;
  float baseSize = 28;
  float seedX, seedY;  // unique noise seeds per fish

  float scale = 1.0;
  float tailPhase = random(TWO_PI);
  int lastFed = millis();
  boolean popped = false;
  float energy = 1.0;

  Fish(PVector p) {
    pos = p.copy();
    vel = PVector.random2D().mult(random(1.2, 2.0));
    acc = new PVector();
    seedX = random(10000);
    seedY = random(10000);
  }

  void update() {
    // hunger → shrink logic
    int aliveMs = millis() - lastFed;

    // drain energy (drains faster after hunger delay)
    float energyDrain = (aliveMs > HUNGER_DELAY_MS) ? 0.0025 : 0.0010;
    energy = constrain(energy - energyDrain, 0.1, 1.0);

    if (aliveMs > HUNGER_DELAY_MS) {
      float hungerT = map(aliveMs, HUNGER_DELAY_MS,
                          HUNGER_DURATION_MS + HUNGER_DELAY_MS, 1, MIN_SCALE);
      scale = constrain(hungerT, MIN_SCALE*0.82, 1.0);
      if (scale <= MIN_SCALE) { popped = true; return; }
    } else {
      scale = lerp(scale, 1.0, 0.05);
    }

    // steering: towards nearest food if any
    Food nearest = nearestFood();
    if (nearest != null) {
      PVector seek = PVector.sub(nearest.pos, pos).limit(0.1);
      acc.add(seek);
      // eat range
      if (PVector.dist(pos, nearest.pos) < baseSize*0.8) {
        nearest.dead = true;
        lastFed = millis();
        scale = 1.0;
        energy = 1.0; // refill energy on eating
      }
    } else {
      // smooth, unbiased per-fish wander
      float t = millis() * 0.0005f;
      float nx = noise(seedX + t) - 0.5f;  // each fish gets its own current
      float ny = noise(seedY + t) - 0.5f;
      acc.add(nx * 0.20f, ny * 0.20f);

      // gentle center pull ONLY when near edges
      float edge = 80;
      if (pos.x < edge || pos.x > W - edge || pos.y < edge || pos.y > H - 120) {
        PVector mid = new PVector(W * 0.5f, H * 0.45f);
        PVector toMid = PVector.sub(mid, pos).mult(0.0006f);
        acc.add(toMid);
      }

      // light damping so small biases don’t snowball
      vel.mult(0.99f);

      // separation: push away from nearby neighbors
      PVector sep = new PVector();
      int n = 0;
      float desired = 34; // personal space radius
      for (Fish other : fishes) {
        if (other == this) continue;
        float d = PVector.dist(pos, other.pos);
        if (d > 0 && d < desired) {
          PVector diff = PVector.sub(pos, other.pos);
          diff.normalize();
          diff.div(d + 0.0001f);
          sep.add(diff);
          n++;
        }
      }
      if (n > 0) {
        sep.div(n);
        sep.limit(0.25f);
        acc.add(sep);
      }
    }

    // wall avoidance
    float margin = 40;
    float steer = 0.15;
    if (pos.x < margin)    acc.x += steer;
    if (pos.x > W-margin)  acc.x -= steer;
    if (pos.y < margin)    acc.y += steer;
    if (pos.y > H-100)     acc.y -= steer;

    // integrate — slower when low energy
    float maxSpeed = 2.6 * (0.6 + 0.4 * energy);
    vel.add(acc).limit(maxSpeed);
    pos.add(vel);
    acc.mult(0);

    tailPhase += 0.2 + vel.mag()*0.05;
  }

  // predator avoidance
  void avoidPoint(PVector p, float radius, float strength) {
    float d = PVector.dist(pos, p);
    if (d < radius) {
      PVector away = PVector.sub(pos, p).normalize().mult(strength*0.25);
      acc.add(away);
    }
  }

  Food nearestFood() {
    if (foods.isEmpty()) return null;
    Food best = null; float bestD = 1e9;
    for (Food f : foods) {
      if (f.dead) continue;
      float d = PVector.dist(pos, f.pos);
      if (d < bestD) { best = f; bestD = d; }
    }
    return best;
  }

  void draw() {
    pushMatrix();
    pushStyle();
    translate(pos.x, pos.y);
    float dir = (vel.x >= 0) ? 1 : -1;
    scale(dir, 1);
    float s = baseSize * scale;

    // body
    noStroke();
    int bodyCol = night ? color(255, 225, 80) : color(255, 205, 0);
    fill(bodyCol);
    ellipse(0, 0, s*1.2, s*0.9);

    // tail wag
    pushMatrix();
    translate(-s*0.65, 0);
    rotate(0.35*sin(tailPhase)*0.6);
    rectMode(CENTER);
    rect(0, 0, s*0.5, s*0.3, s*0.2);
    popMatrix();

    // fins
    fill(255, 220);
    ellipse(s*0.1, -s*0.2, s*0.3, s*0.18);
    ellipse(s*0.2,  s*0.18, s*0.22, s*0.14);

    // cheek blush
    fill(255, 120, 140, 160);
    ellipse(s*0.18, s*0.05, s*0.22, s*0.16);

    // eye
    fill(0);
    ellipse(s*0.25, -s*0.06, s*0.18, s*0.18);
    fill(255);
    ellipse(s*0.27, -s*0.08, s*0.07, s*0.07);

    // energy bar (0..1)
    if (scene == Scene.GAME) {
      rectMode(CORNER);
      float barW = s * 0.8;
      float barH = 5;
      float barX = -barW/2;
      float barY = -s * 0.85;

      // background
      noStroke();
      fill(0, 70);
      rect(barX, barY, barW, barH, 3);

      // color gradient red to yellow to green based on energy
      int cLow = color(240, 90, 90);
      int cMid = color(255, 200, 80);
      int cHi  = color(80, 200, 120);
      float t = energy; // 0..1
      int barCol = (t < 0.5)
        ? lerpColor(cLow, cMid, map(t, 0, 0.5, 0, 1))
        : lerpColor(cMid, cHi,  map(t, 0.5, 1, 0, 1));
      fill(barCol);
      rect(barX, barY, barW * energy, barH, 3);

      rectMode(CENTER);
    }
    popStyle();
    popMatrix();
  }
}

class Food {
  PVector pos, vel;
  boolean dead = false;
  int born = millis();
  int life = 14000;

  Food(PVector start) {
    pos = start.copy();
    vel = new PVector(0, random(1.2, 2.1));
  }

  void update() {
    vel.y += 0.01; // gravity-ish
    pos.add(vel);
    if (pos.y > H-100) { pos.y = H-100; vel.set(0,0); } // settle on sand
    if (millis() - born > life) dead = true;
  }

  void draw() {
    if (dead) return;
    noStroke();
    fill(150, 110, 60, 220);
    ellipse(pos.x, pos.y, 6, 4);
  }
}

class Bubble {
  PVector pos;
  float r = random(6, 18);
  float vy = random(-2.4, -1.2);
  int born = millis();
  int life = 1200 + int(random(700));
  boolean dead = false;

  Bubble(PVector p) { pos = p.copy(); }

  void update() {
    pos.y += vy;
    pos.x += sin(frameCount*0.2 + pos.y*0.05)*0.8;
    if (millis()-born > life || pos.y < -20) dead = true;
  }

  void draw() {
    noFill();
    stroke(255, 120);
    strokeWeight(2);
    ellipse(pos.x, pos.y, r, r);
  }
}

// Starfish class (static props on the sand)
class Starfish {
  PVector pos;
  float r;           // base radius
  float rot;         // rotation
  boolean big;       // big = fish-sized look
  float wobbleSeed;  // tiny breathing wobble

  Starfish(PVector p, float radius, float rotation, boolean big) {
    this.pos = p.copy();
    this.r = radius;
    this.rot = rotation;
    this.big = big;
    this.wobbleSeed = random(1000);
  }

  void draw(PGraphics g, boolean nightMode) {
    g.pushStyle();
    g.pushMatrix();
    g.translate(pos.x, pos.y);
    g.rotate(rot);

    // subtle breathing so it feels alive
    float wob = 1.0 + 0.015 * sin((frameCount * 0.03f) + wobbleSeed);
    g.scale(wob);

    // colors
    int body = nightMode ? g.color(235, 60, 120) : g.color(255, 70, 150);
    int edge = nightMode ? g.color(170, 30, 90, 180) : g.color(200, 40, 110, 180);

    g.noStroke();
    g.fill(body);

    // 5-armed rounded star via 10 vertices
    g.beginShape();
    for (int i = 0; i < 10; i++) {
      float ang = i * TWO_PI / 10.0;
      float rad = (i % 2 == 0) ? r : r * 0.45f;
      float x = cos(ang) * rad;
      float y = sin(ang) * rad;
      g.vertex(x, y);
    }
    g.endShape(CLOSE);

    // inner edge line for a little volume
    g.noFill();
    g.stroke(edge);
    g.strokeWeight(2);
    g.beginShape();
    for (int i = 0; i < 10; i++) {
      float ang = i * TWO_PI / 10.0;
      float rad = (i % 2 == 0) ? r * 0.88f : r * 0.40f;
      g.vertex(cos(ang) * rad, sin(ang) * rad);
    }
    g.endShape(CLOSE);

    // cute face for big ones
    if (big) {
      g.noStroke();
      g.fill(255);
      g.ellipse(-r*0.25f, -r*0.10f, r*0.28f, r*0.28f);
      g.ellipse( r*0.10f, -r*0.10f, r*0.28f, r*0.28f);
      g.fill(0);
      g.ellipse(-r*0.25f, -r*0.10f, r*0.12f, r*0.12f);
      g.ellipse( r*0.10f, -r*0.10f, r*0.12f, r*0.12f);
      g.noFill();
      g.stroke(0, 60);
      g.strokeWeight(max(1, r*0.06f));
      g.arc(-r*0.08f, r*0.10f, r*0.7f, r*0.45f, 0.1f, PI-0.1f);
    }

    g.popMatrix();
    g.popStyle();
  }
}

// ------------- UI helpers -------------
class Icon {
  float x,y,s; String label;
  Icon(float x,float y,float s,String label){this.x=x;this.y=y;this.s=s;this.label=label;}
  void draw(){
    pushStyle();
    noStroke();
    fill(255, 230);
    rectMode(CENTER);
    rect(x,y,s+10,s+10,12);
    fill(20);
    textAlign(CENTER, CENTER);
    textSize( (label=="•")? 26 : 18 );
    text(label,x,y-2);
    popStyle();
  }
  boolean hit(float mx,float my){ return mx> x-(s+10)/2 && mx< x+(s+10)/2 && my> y-(s+10)/2 && my< y+(s+10)/2; }
}

class Toggle {
  float x,y,w;
  Toggle(float x,float y,float w){this.x=x;this.y=y;this.w=w;}
  void draw(boolean on){
    float h = 28;
    noStroke();
    fill(on? color(40,60,120,220) : color(240,240,240,230));
    rect(x, y-14, w, h, 16);
    float knobX = on? x+w-18 : x+18;
    fill(255);
    ellipse(knobX, y, 22, 22);
    fill(on? color(230, 230, 255): color(255, 210, 40));
    if (on) ellipse(knobX-3, y-3, 10, 10);
    else    ellipse(knobX,   y,   12, 12);
  }
  boolean hit(float mx,float my){ return mx>x && mx<x+w && my>y-16 && my<y+16; }
}

class RectButton {
  float x,y,w,h; String t;
  RectButton(float x,float y,float w,float h,String t){this.x=x;this.y=y;this.w=w;this.h=h;this.t=t;}
  void draw(){
    fill(250);
    stroke(0, 80);
    rect(x,y,w,h,5);
    fill(20);
    textAlign(CENTER, CENTER);
    text(t, x+w/2, y+h/2-1);
  }
  boolean hit(float mx,float my){ return mx>x && mx<x+w && my>y && my<y+h; }
}

// -------------------- RESTART GAME --------------------
void drawRestartButton() {
  // position: left margin, vertically aligned with the toggle
  restartW = 110;
  restartH = 36;
  restartX = 20;
  restartY = dayNightToggle.y - restartH/2;

  noStroke();
  fill(230, 80, 100);
  rect(restartX, restartY, restartW, restartH, 10);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(14);
  text("Restart", restartX + restartW/2, restartY + restartH/2 + 1);
}

