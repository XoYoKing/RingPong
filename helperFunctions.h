#import "math.h"

double angleFromCoordinates(double x, double y) {
	double angle;
	if (y >= 0 && x > 0) {
		angle = atan(y/x) * 180 / M_PI;
	} else if (y >= 0 && x < 0) {
		angle = 180 + atan(y/x) * 180 / M_PI;
	} else if (y < 0 && x < 0) {
		angle = 180 + atan(y/x) * 180 / M_PI;
	} else if (y < 0 && x > 0) {
		angle = 360 + atan(y/x) * 180 / M_PI;
	} else if (y > 0 && x == 0) {
		angle = 90;
	} else if (y < 0 && x == 0){
		angle = 270;
	} else {
		// this should never happen
		// case where x = y = 0
		angle = 0;
	}
	return angle;
}