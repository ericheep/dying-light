// dying-light.ck
// Eric Heep

// communication classes
HandshakeID talk;
3.5::second => now;
talk.talk.init();
2.5::second => now;

6 => int NUM_PUCKS;
16 => int NUM_LEDS;

// led class
Puck puck[NUM_PUCKS];

for (0 => int i; i < NUM_PUCKS; i++) {
    puck[i].init(i);
}

float puckValue[NUM_PUCKS];
float puckColor[NUM_PUCKS];
float hue[NUM_PUCKS][NUM_LEDS];
float value[NUM_PUCKS][NUM_LEDS];

5.0 => float decibelThreshold;
75::ms => dur baseSpeed;

// led behavior
2 => int NUM_LINES;

float ledSpeed[NUM_LINES];
float ledWidth[NUM_LINES];
float sinBuild[NUM_LINES];

int linePhase[NUM_LINES];
int sinPhase[NUM_LINES];
int blinkPhase[NUM_LINES];

for (int i; i < NUM_LINES; i++) {
    0 => linePhase[i];
    0 => sinPhase[i];
    1 => blinkPhase[i];
}

// audio
Gain gain;
Analyze ana[2];
for (0 => int i; i < 2; i++) {
    adc.chan(i) => gain => dac;
    adc.chan(i) => ana[i];
}

fun int convert(float value, int scale) {
    return Std.clamp(Math.floor(value * scale) $ int, 0, scale);
}

fun void updateColors() {
    for (int i; i < NUM_PUCKS; i++) {
        for (int j; j < 16; j++) {

            puck[i].color(j,
                        convert(0.85, 1023),  // hue
                        255,               // saturation
                        convert(value[i][j] * 127, 255)  // value
                        );
        }
    }
}

[[15, 14, 13, 12, 11],
 [ 4,  3,  2,  1,  0]] @=> int matrix[][];


fun void circle(int which) {
    matrix[which].size() => int shieldLength;
    NUM_PUCKS * matrix[which].size() => int rowLength;
    int rowLed, dirLed, led, shield, width, modLed;

    while (true) {
        while (linePhase[which] == 1) {
            (rowLed + 1) % rowLength => rowLed;

            // incrementer
            if (which == 0) {
                rowLed => dirLed;
            }
            else if (which == 1) {
                (rowLength - 1) - rowLed => dirLed;
            }

            1.0 => value[dirLed / shieldLength][matrix[which][dirLed % shieldLength]];

            baseSpeed * (Math.pow((-ledSpeed[which] + 1.0), 3) + 0.15) => now;

            // clear previous led
            clearRow(which);

            if (rowLed == rowLength - 1) {
                repeat(rowLength) {
                    baseSpeed * (Math.pow((-ledSpeed[which] + 1.0), 3) + 0.15) => now;
                }
            }
        }

        float sinInc;

        while (sinPhase[which] == 1) {
            (ledWidth[which] * rowLength)$int => width;

            // incrementer
            (sinInc + 0.1) % (2 * pi) => sinInc;

            Math.floor(((Math.sin(sinInc) + 1.0) / 2.0) * rowLength)$int => rowLed;

            1.0 => value[rowLed / shieldLength][matrix[which][rowLed % shieldLength]];

            for (0 => int i; i < width; i++) {
                (rowLed + (i + 1)) % rowLength => modLed;
                1.0 => value[modLed / shieldLength][matrix[which][modLed % shieldLength]];
            }

            baseSpeed * (Math.pow((-ledSpeed[which] + 1.0), 3) + 0.15) => now;

            // clear previous led
            clearRow(which);
        }

        while (blinkPhase[which] == 1) {
            Math.random2(0, NUM_PUCKS - 1) => shield;

            for (0 => int i; i < shieldLength; i++) {
                1.0 => value[shield][matrix[which][i]];
            }

            baseSpeed * (Math.pow((-ledSpeed[which] + 1.0), 3) + 0.15) => now;

            // clear previous led
            clearRow(which);
        }
    }
}

fun void clearRow(int which) {
    for (0 => int i; i < NUM_PUCKS; i++) {
        for (0 => int j; j < matrix[which].size(); j++) {
            0.0 => value[i][matrix[which][j]];
        }
    }
}

fun void speed(int which) {
    while (true) {
        if (ana[which].decibel() > decibelThreshold) {
            if (linePhase[which]) {
                ledSpeed[which] + 0.001 => ledSpeed[which];
            }
            if (sinPhase[which]) {
                ledSpeed[which] + 0.001 => ledSpeed[which];
                ledWidth[which] + 0.001 => ledWidth[which];
            }
            if (blinkPhase[which]) {
                ledSpeed[which] - 0.0003 => ledSpeed[which];
            }
        }
        else if (ana[which].decibel() <= decibelThreshold) {
            if (linePhase[which]) {
                ledSpeed[which] - 0.0003 => ledSpeed[which];
            }
            if (sinPhase[which]) {
                ledSpeed[which] - 0.0003 => ledSpeed[which];
                ledWidth[which] - 0.0003 => ledWidth[which];
            }
            if (blinkPhase[which]) {
                ledSpeed[which] + 0.001 => ledSpeed[which];
            }
        }

        // clamps
        Std.clampf(ledSpeed[which], 0.0, 1.0) => ledSpeed[which];
        Std.clampf(ledWidth[which], 0.0, 1.0) => ledWidth[which];

        if (ledSpeed[which] >= 1.0 && linePhase[which] == 1) {
            0 => linePhase[which];
            1 => sinPhase[which];
        }
        if (ledWidth[which] >= 1.0 && sinPhase[which] == 1) {
            0 => sinPhase[which];
            1 => blinkPhase[which];
        }
        if (ledSpeed[which] <= 0.0 && blinkPhase[which] == 1) {
            0 => blinkPhase[which];
            1 => linePhase[which];
        }

        10::ms => now;
    }
}

spork ~ circle(0);
spork ~ circle(1);

spork ~ speed(0);
spork ~ speed(1);

while (true) {
    // send hsv values to pucks
    updateColors();
    (1.0/30.0)::second => now;
}
