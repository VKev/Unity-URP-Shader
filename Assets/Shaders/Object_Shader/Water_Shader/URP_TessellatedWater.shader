Shader "MyCustom_URP_Shader/URP_TessellatedWater" {
    Properties{
        _FactorEdge1("Edge factors", Vector) = (1, 1, 1, 0)

        _FactorInside("Inside factor", Float) = 1

        _MainTex ("Texture", 2D) = "white" {}
        _TextureBlend("Texture blend Intensity",float) =1
        _Depth ("Depth", float) = 10
        _SurfaceColor("Surface Color",COLOR) = (0.4 ,0.9 ,1 ,0.27 )
        _BottomColor("Bottom Color",COLOR) = (0.1 ,0.1 ,0.5 ,1 )

        _WaveSpeed("Wave speed", float) = 0.5
        _WaveScale("Wave scale", float) = 15
        _WaveStrength("Wave damping", float) = 0.1
        _NoiseNormalStrength("Wave strength", float) = 0.1
        _FoamAmount("Foam amount",float) = 1
        _FoamCutoff("Foam cutoff",float) = 2.5
        _FoamSpeed("Foam speed",float) = 0.05
        _FoamScale("Foam scale",float) = 2
        _FoamColor("Foam color", COLOR) = (1,1,1,0.5)
        _Gloss("Gloss", float) = 1
        _Smoothness("Smoothness",float)=1
        _SpecularIntensity("Specular Intensity",float) = 0.15
        _WaterShadow("Shadow Intensity",float) = -0.5
    }
    SubShader{
        Tags{"RenderType" = "Transparent" "Queue" = "Transparent" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}
        LOD 100
        ZWrite Off
        Cull Off
        Pass {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            HLSLPROGRAM
            #pragma target 5.0 // 5.0 required for tessellation

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #pragma vertex Vertex
            #pragma hull Hull
            #pragma domain Domain
            #pragma fragment Fragment

            #ifndef TESSELLATION_FACTORS_INCLUDED
            #define TESSELLATION_FACTORS_INCLUDED
            #define _SPECULAR_COLOR
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Assets/VkevShaderLib.hlsl"

            struct Attributes {
                float3 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS: TANGENT;
                float2 uv: TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct TessellationControlPoint {
                float3 positionWS : INTERNALTESSPOS;
                float3 normalWS : NORMAL;
                float3 tangentWS:TANGENT;
                float3 biTangent: TEXCOORD1;
                float4 screenPosition: TEXCOORD3;
                float2 waterUV: TEXCOORD2;
                float2 foamUV: TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct TessellationFactors {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };

            

            struct domaOut {
                float4 positionCS  : SV_POSITION;
                float2 waterUV:TEXCOORD0;
                float2 foamUV:TEXCOORD5;
                float4 screenPosition: TEXCOORD1;
                float3 normalWS: NORMAL;
                float3 tangentWS : TEXCOORD3;
                float3 biTangent : TEXCOORD2;
                float3 positionWS: TEXCOORD4;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            sampler2D _CameraOpaqueTexture;
            CBUFFER_START(UnityPerMaterial)
                float3 _FactorEdge1;
                float _FactorInside;
                sampler2D _MainTex;
                float _TextureBlend;
                float4 _MainTex_ST;
                half4 _BaseColor;
                half4 _FoamColor;
                half4 _SurfaceColor;
                half4 _BottomColor;
                float _Depth;
                float _WaveSpeed;
                float _WaveScale;
                float _WaveStrength;
                float _FoamAmount;
                float _FoamCutoff;
                float _FoamSpeed;
                float _FoamScale;
                float _SpecularIntensity;
                float _Gloss;
                float _Smoothness;
                float _NoiseNormalStrength;
                float _WaterShadow;
            CBUFFER_END

            float3 GetViewDirectionFromPosition(float3 positionWS) {
                return normalize(GetCameraPositionWS() - positionWS);
            }

            

            TessellationControlPoint Vertex(Attributes input) {
                TessellationControlPoint output;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);

                _MainTex_ST.zw += _Time.y*_WaveSpeed;
                _MainTex_ST.xy *= _WaveScale;
                output.waterUV = TRANSFORM_TEX(input.uv, _MainTex);

                _MainTex_ST.zw += _Time.y*_FoamSpeed;
                _MainTex_ST.xy *= _FoamScale;
                output.foamUV = TRANSFORM_TEX(input.uv, _MainTex);

                VertexPositionInputs posnInputs = GetVertexPositionInputs(input.positionOS);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);

                output.tangentWS = GetVertexNormalInputs(input.normalOS,input.tangentOS).tangentWS;
                output.normalWS = normalInputs.normalWS;
                output.biTangent = cross(output.normalWS, output.tangentWS)
                              * (input.tangentOS.w) 
                              * (unity_WorldTransformParams.w);
                
                output.positionWS = posnInputs.positionWS;
                output.screenPosition = ComputeScreenPos(TransformObjectToHClip(input.positionOS.xyz));
                return output;
            }

            // The patch constant function runs once per triangle, or "patch"
            // It runs in parallel to the hull function
            TessellationFactors PatchConstantFunction(
                InputPatch<TessellationControlPoint, 3> patch) {
                UNITY_SETUP_INSTANCE_ID(patch[0]); // Set up instancing
                // Calculate tessellation factors
                TessellationFactors f;
                f.edge[0] = _FactorEdge1.x;
                f.edge[1] = _FactorEdge1.y;
                f.edge[2] = _FactorEdge1.z;
                f.inside = _FactorInside;
                return f;
            }

            // The hull function runs once per vertex. You can use it to modify vertex
            // data based on values in the entire triangle
            [domain("tri")] // Signal we're inputting triangles
            [outputcontrolpoints(3)] // Triangles have three points
            [outputtopology("triangle_cw")] // Signal we're outputting triangles
            [patchconstantfunc("PatchConstantFunction")] // Register the patch constant function
            [partitioning("integer")]
            TessellationControlPoint Hull(
                InputPatch<TessellationControlPoint, 3> patch, // Input triangle
                uint id : SV_OutputControlPointID) { // Vertex index on the triangle

                return patch[id];
            }

            // Call this macro to interpolate between a triangle patch, passing the field name
            #define BARYCENTRIC_INTERPOLATE(fieldName) \
		            patch[0].fieldName * barycentricCoordinates.x + \
		            patch[1].fieldName * barycentricCoordinates.y + \
		            patch[2].fieldName * barycentricCoordinates.z

            // The domain function runs once per vertex in the final, tessellated mesh
            // Use it to reposition vertices and prepare for the fragment stage
            [domain("tri")] // Signal we're inputting triangles
            domaOut Domain(
                TessellationFactors factors, // The output of the patch constant function
                OutputPatch<TessellationControlPoint, 3> patch, // The Input triangle
                float3 barycentricCoordinates : SV_DomainLocation) { // The barycentric coordinates of the vertex on the triangle

                domaOut output;

                // Setup instancing and stereo support (for VR)
                UNITY_SETUP_INSTANCE_ID(patch[0]);
                UNITY_TRANSFER_INSTANCE_ID(patch[0], output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                float3 positionWS = BARYCENTRIC_INTERPOLATE(positionWS);
                float3 normalWS = BARYCENTRIC_INTERPOLATE(normalWS);
                float3 tangentWS = BARYCENTRIC_INTERPOLATE(tangentWS);
                float2 waterUV = BARYCENTRIC_INTERPOLATE(waterUV);
                float2 foamUV = BARYCENTRIC_INTERPOLATE(foamUV);
                float4 screenPosition = BARYCENTRIC_INTERPOLATE(screenPosition);
                float3 biTangent = BARYCENTRIC_INTERPOLATE(biTangent);
                
                float waterGradientNoise;
                Unity_GradientNoise_float(waterUV, 1, waterGradientNoise);
                positionWS.y += _WaveStrength*(2*waterGradientNoise-1);

                output.waterUV = waterUV;
                output.foamUV = foamUV;
                output.screenPosition = screenPosition;
                output.tangentWS = tangentWS;
                output.positionCS = TransformWorldToHClip(positionWS);
                output.normalWS = normalWS;
                output.biTangent = biTangent;
                output.positionWS = positionWS;

                return output;
            }
            float DepthFade (float rawDepth,float strength, float4 screenPosition){
                float sceneEyeDepth = LinearEyeDepth(rawDepth, _ZBufferParams);
                float depthFade = sceneEyeDepth;
                depthFade -= screenPosition.a;
                depthFade /= strength;
                depthFade = saturate(depthFade);
                return depthFade;
            }

            float4 Fragment(domaOut i) : SV_Target{
                UNITY_SETUP_INSTANCE_ID(i);
                float2 screenSpaceUV = i.screenPosition.xy/i.screenPosition.w;
                
                float rawDepth = SampleSceneDepth(screenSpaceUV);
                float depthFade = DepthFade(rawDepth,_Depth, i.screenPosition);
                float4 waterDepthCol = lerp(_BottomColor,_SurfaceColor,1-depthFade);




                float waterGradientNoise;
                Unity_GradientNoise_float(i.waterUV, 1, waterGradientNoise);

                float3 gradientNoiseNormal;
                float3x3 tangentMatrix = float3x3(i.tangentWS, i.biTangent,i.normalWS);
                Unity_NormalFromHeight_Tangent_float(waterGradientNoise, 0.1,i.positionWS,tangentMatrix,gradientNoiseNormal);
                gradientNoiseNormal *= _NoiseNormalStrength;

                gradientNoiseNormal += i.screenPosition.xyz ;
                float4 gradientNoiseScreenPos = float4(gradientNoiseNormal,i.screenPosition.w );
                float4 waterDistortionCol = tex2Dproj(_CameraOpaqueTexture,gradientNoiseScreenPos);



                float foamDepthFade = DepthFade(rawDepth,_FoamAmount, i.screenPosition);
                foamDepthFade *= _FoamCutoff;

                float foamGradientNoise;
                Unity_GradientNoise_float(i.foamUV, 1, foamGradientNoise);

                float foamCutoff = step(foamDepthFade, foamGradientNoise);
                foamCutoff *= _FoamColor.a;

                float4 foamColor = lerp(waterDepthCol, _FoamColor, foamCutoff);


                float4 mainTex = tex2D(_MainTex,i.waterUV);
                float4 finalCol = lerp(waterDistortionCol, foamColor, foamColor.a);
                finalCol = lerp(mainTex,finalCol,_TextureBlend);




                float3 gradientNoiseNormalWS;
                Unity_NormalFromHeight_World_float(waterGradientNoise,0.1,i.positionWS,tangentMatrix,gradientNoiseNormalWS);

                InputData inputData = (InputData)0;//declare InputData struct
                inputData.normalWS = gradientNoiseNormalWS;// if front face return 1 else return -1
                inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(i.positionWS);//get view dir base on positionWS

               
                SurfaceData surfaceData = (SurfaceData)0;//declare SurfaceData 
                surfaceData.albedo = float3(1,1,1)*_WaterShadow;
                surfaceData.alpha = 1;
                surfaceData.specular = _Gloss;
                surfaceData.smoothness = _Smoothness;
                
               //return float4( gradientNoiseNormalWS,1);
               return finalCol +UniversalFragmentBlinnPhong(inputData , surfaceData)*_SpecularIntensity;
                //return float4(normalize(input.normalWS),1);
            }

            #endif
            ENDHLSL
        }
    }
}