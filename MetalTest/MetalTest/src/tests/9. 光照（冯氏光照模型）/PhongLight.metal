////  PhongLight.metal
//  MetalTest
//
//  Created by Su Jinjin on 2020/6/10.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

typedef struct
{
    float4 position [[position]];
    
    float3 vertexNormal;
    
    float3 fragmentPosition;
    
} VertexOut;

vertex VertexOut
PhongLightVertexShader(
                       uint vertexID [[ vertex_id ]],
                       constant packed_float3 *position [[ buffer(0) ]], // 位置
                       constant packed_float3 *normal [[ buffer(1) ]], // 法线
                       constant float4x4 *modelMatrix [[ buffer(2) ]], // 本地变换矩阵
                       constant float4x4 *viewMatrix [[ buffer(3) ]], // 观察矩阵
                       constant float4x4 *projectionMatrix [[ buffer(4) ]] // 投影矩阵
                       ) {
    VertexOut out;
    
    out.position = projectionMatrix[0] * viewMatrix[0] * modelMatrix[0] * float4(position[vertexID], 1);
    out.vertexNormal = (modelMatrix[0] * float4(normal[vertexID], 0)).rgb;
    out.fragmentPosition = (modelMatrix[0] * float4(position[vertexID], 1)).rgb;
    
    return out;
}

fragment float4
PhongLightFragmentShader(
                         VertexOut in [[ stage_in ]],
                         constant float3 *originColor [[ buffer(0) ]], // 当前渲染对象的颜色
                         constant bool *needLight [[ buffer(1) ]], // 是否需要渲染光线（光源无需反光）
                         constant float3 *lightColor [[ buffer(2) ]], // 光源颜色
                         constant float *ambientStrength [[ buffer(3) ]], // 环境光强度
                         constant float3 *lightPos [[ buffer(4) ]], // 光源的位置
                         constant float3 *eyePos [[ buffer(5) ]], // 眼睛（摄像机）的位置
                         constant float *specularStrength [[ buffer(6) ]] // 镜面反射的强度
                         ) {
    
    float3 color;
    
    if (needLight[0]) {
        
        // Ambient
        float3 ambient = ambientStrength[0] * lightColor[0];
        
        // Diffuse
        float3 norm = normalize(in.vertexNormal);
        float3 lightDir = normalize(lightPos[0] - in.fragmentPosition);
        
        float diff = max(dot(norm, lightDir), 0.0);
        float3 diffuse = diff * lightColor[0];
        
        // Specular
        float3 eyeDir = normalize(eyePos[0] - in.fragmentPosition); // 视线方向
        float3 reflectDir = reflect(-lightDir, norm); // 光线反射的方向
        
        float3 spec = pow(max(dot(eyeDir, reflectDir), 0.0), 32.0);
        float3 specular = specularStrength[0] * spec * lightColor[0];
        
        color = (ambient + diffuse + specular) * originColor[0];
        
    } else {
        
        color = originColor[0];
        
    }
    return float4(color, 1);
}
