#define vc_steps 20
#define vc_altitude 512.0
#define vc_thickness 384.0
#define vc_breakThreshold 0.05

vec3 planetCurvePosition(in vec3 x) {
    return vec3(x.x, length(x + vec3(0.0, atmosphere_planetRadius, 0.0))-atmosphere_planetRadius, x.z);
}

void getVolumeClouds(inout vec3 scenecolor, vec3 viewvec, vec3 upvec, vec3 camerapos, float vdotl, float dither) {
    vec3 wvec   = mat3(gbufferModelViewInverse)*viewvec;
    vec2 psphere = rsi((atmosphere_planetRadius+eyeAltitude)*upvec, viewvec, atmosphere_planetRadius);
    bool visible = !((eyeAltitude<vc_altitude && psphere.y>0.0) || (eyeAltitude>(vc_altitude+vc_thickness) && wvec.y>0.0));

    if (visible) {
        const float lowEdge     = vc_altitude;
        const float highEdge    = vc_altitude+vc_thickness;

        vec2 bsphere    = rsi(vec3(0.0, 1.0, 0.0)*atmosphere_planetRadius+eyeAltitude, wvec, atmosphere_planetRadius+lowEdge);
        vec2 tsphere    = rsi(vec3(0.0, 1.0, 0.0)*atmosphere_planetRadius+eyeAltitude, wvec, atmosphere_planetRadius+highEdge);

        float startdist = eyeAltitude>highEdge ? tsphere.x : bsphere.y;
        float enddist   = eyeAltitude>highEdge ? bsphere.x : tsphere.y;

        vec3 startpos   = wvec*startdist;
        vec3 endpos     = wvec*enddist;

        startpos    = planetCurvePosition(startpos);
        endpos      = planetCurvePosition(endpos);

        vec3 bstep      = (endpos-startpos)/vc_steps;
        const float blength = s_vcThickness/vc_steps;
        float stepsCoeff = length(bstep)/blength;
            stepsCoeff  = 0.5+clamp(stepsCoeff-1.25, 0.0, 3.0)*0.4;
        int steps       = int(vc_steps*stepsCoeff);

        vec3 rstep  = (endpos-startpos)/steps;
        vec3 rpos   = rstep*dither+startpos+camerapos;

        float rlength = length(rstep);

        vec2 scatter    = vec2(0.0);
        float transmittance = 1.0;
        float fade      = 1.0;

        vec3 sunlight   = vec3(1.0, 1.0, 1.0)*10.0;
        vec3 skylight   = vec3(0.2, 0.4, 1.0)*2.0;

        float oDmult    = sqrt(steps/(rlength*1.73205080757));

        for (int i = 0; i<steps; ++i, rpos += rstep) {
            if (rpos.y<lowEdge || rpos.y>highEdge || transmittance<vc_breakThreshold) continue;
            float dist  = length(rpos-camerapos);
            float dfade = clamp((dist-500.0)/40000, 0.0, 1.0);
            if ((1.0-dfade)<0.01) continue;

            
        }
    }
}