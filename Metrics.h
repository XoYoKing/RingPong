// I should move a lot of these settings into a preference panel

#define RING_RADIUS 0.4
#define RING_HALF_THICKNESS 0.0025
#define BALL_RADIUS 0.01
#define PADDLE_LENGTH 30.0
#define PADDLE_HALF_THICKNESS 0.025
#define FRICTION_BETWEEN_BALL_AND_PADDLE 0.5
#define MAX_PADDLE_SPEED 90.0
#define MIN_BALL_SPEED 0.15
#define RANDOM_BALL_SPAWNING_IS_ENABLED YES

// new guys... only used in Player.m so far (could be used for ball fades as well)
// alternatively, I could use the alpha value of the loser for the alpha value of the ball during a "loose"
#define AG_FADE_RATE 2.5
#define AG_LOSER_FADE_RATE 0.8

// these are just testing values
//#define AG_FADE_RATE 2.0
//#define AG_LOSER_FADE_RATE 0.4