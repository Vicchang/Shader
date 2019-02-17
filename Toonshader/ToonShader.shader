// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/ToonShader"
{
	Properties
	{
		_SpecularColor ("SPECULAR", Color) = (1,1,1,1)
		_Specular	   ("Specular size", Range(0.5,1)) = 0.72
		_FadeSpecular  ("Specular blur", Range(0,1)) = 0

		_DiffuseColor  ("DIFFUSE", Color) = (0.5,0.5,0.5,1)
		_Diffuse	   ("Diffuse size", Range(-1.1,1)) = 0.1
		_FadeDiffuse   ("Diffuse blur", Range(0,1)) = 0

		_ShadowColor   ("SHADOW", Color) = (0.25,0.25,0.25,1)
		_FadeShadow    ("Shadow blur", Range(0,1)) = 0

		_OutlineColor  ("OUTLINE", Color) = (0,0,0,1)
		_Outline	   ("Outline size", Range(1.0,3.0)) = 1.5

		_MainTex	   ("Texture", 2D) = "white" {}
		_TexAlpha	   ("Texture alpha", Range(0,1)) = 0
	}
	SubShader
	{
		Tags { "LightMode" = "ForwardBase" }
		Tags { "RenderType"="Opaque" }
		Tags { "Queue"="Transparent"}

		Pass
		{
			ZWrite Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			struct vertexInput
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};

			struct vertexOutput
			{
				float4 pos : POSITION;
				float3 normal : NORMAL;
			};

			uniform float4 _OutlineColor;
			uniform float _Outline;

			vertexOutput vert(vertexInput Input)
			{
				vertexOutput Output;

				Input.vertex.xyz *= _Outline;

				Output.pos = UnityObjectToClipPos(Input.vertex);

				return Output;
			}

			fixed4 frag(vertexOutput Input) : COLOR 
			{
				return _OutlineColor;
			}
			ENDCG
		}

		Pass
		{
			ZWrite On
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"

			struct vertexInput
			{
				float4 vertex : POSITION;
				float3 normal :NORMAL;
				float2 uv : TEXCOORD0;
			};

			struct vertexOutput
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float3 normalDir : TEXCOORD1;
				float4 lightDir : TEXCOORD2;
				float3 viewDir : TEXCOORD3;
			};

			uniform float4 _DiffuseColor;
			uniform float4 _ShadowColor;
			uniform float3 _SpecularColor;

			uniform float _Diffuse;
			uniform float _FadeDiffuse;
			
			uniform float _Specular;
			uniform float _FadeSpecular;

			uniform float _FadeShadow;
			
			//uniform float _Outline;
			//uniform float4 _OutlineColor;
			
			uniform float _TexAlpha;

			uniform float4 _LightColor0;
			uniform sampler2D _MainTex;
			uniform float4 _MainTex_ST;
			
			vertexOutput vert (vertexInput input)
			{
				vertexOutput output;

				// normal direction
				output.normalDir = normalize(mul(float4(input.normal, 0.0), unity_WorldToObject).xyz);
				
				// world position
				float4 posWorld = mul(unity_ObjectToWorld, input.vertex);
				
				// view direction
				output.viewDir = normalize(_WorldSpaceCameraPos.xyz - posWorld.xyz);
				
				// light direction
				float3 fragmentToLightSource = (_WorldSpaceCameraPos.xyz - posWorld.xyz);
				output.lightDir = float4(
					normalize(lerp(_WorldSpaceLightPos0.xyz, fragmentToLightSource, _WorldSpaceLightPos0.w)),
					lerp(1.0, 1.0 / length(fragmentToLightSource), _WorldSpaceLightPos0.w)
				);
				
				// fragmentInput output
				output.vertex = UnityObjectToClipPos(input.vertex);

				// UV Map
				output.uv = input.uv;

				return output;
			}
			
			fixed4 frag (vertexOutput input) : COLOR
			{
				float nDotL = saturate(dot(input.normalDir, input.lightDir.xyz));

				//Diffuse threshold calculation
				float diffuseCutoff = saturate((max(_Diffuse, nDotL) - _Diffuse) * (1 - _FadeDiffuse) * 60);

				//Specular threshold calculation
				float specularCutoff = saturate(max(_Specular, dot(reflect(-input.lightDir.xyz, input.normalDir), input.viewDir)) - _Specular) * (1 - _FadeSpecular) * 100;

				//Calculate Outlines
				//float outlineStrength = saturate((dot(input.normalDir, input.viewDir) - _Outline) * (1 - _FadeShadow) * 200);


				float3 ambientLight = (1 - _TexAlpha) *(1 - diffuseCutoff) * _ShadowColor.xyz + _TexAlpha * tex2D(_MainTex, input.uv);
				float3 diffuseReflection = (1 - specularCutoff) * _DiffuseColor.xyz * diffuseCutoff;
				float3 specularReflection = _SpecularColor.xyz * specularCutoff;

				//float3 combinedLight = _OutlineColor * (1 - outlineStrength) + (ambientLight + diffuseReflection) * outlineStrength + specularReflection;
				float3 combinedLight =  (ambientLight + diffuseReflection) + specularReflection;

				return float4(combinedLight, 1.0);
			}
			ENDCG
		}
	}

	Fallback "Diffuse"
}
