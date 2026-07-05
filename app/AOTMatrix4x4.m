#import "AOTMatrix4x4.h"

@implementation AOTMatrix4x4 {
    float m[4][4];
}

+ (instancetype)identity {
    AOTMatrix4x4 *mat = [[AOTMatrix4x4 alloc] init];
    memset(mat->m, 0, sizeof(mat->m));
    for (int i = 0; i < 4; i++) mat->m[i][i] = 1.0;
    return mat;
}

+ (AOTMatrix4x4)getViewProjectionMatrix {
    // mock matrix - real impl would read from game memory
    AOTMatrix4x4 mat = *[AOTMatrix4x4 identity];
    return mat;
}

- (AOTVector3)multiplyVector:(AOTVector3)v {
    AOTVector3 result = {0, 0, 0};
    // simple transform
    result.x = v.x * m[0][0] + v.y * m[0][1] + v.z * m[0][2] + m[0][3];
    result.y = v.x * m[1][0] + v.y * m[1][1] + v.z * m[1][2] + m[1][3];
    result.z = v.x * m[2][0] + v.y * m[2][1] + v.z * m[2][2] + m[2][3];
    return result;
}

@end
