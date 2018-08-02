Shader "Hidden/RampTex"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_RampTex("Ramp Tex",2D) = "white"{}
		_Color("Color Tint",Color) = (1,1,1,1)
		_Specular("Specular", Color) = (1,1,1,1)
		_Gloss("Gloss", Float) = 8
	}
	SubShader
	{
		Cull Off ZWrite on ZTest on

		Pass
		{
			Tags{"LightMode" = "ForwardBase"}

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "Lighting.cginc"


			sampler2D _MainTex;
			sampler2D _RampTex;

			float4 _MainTex_ST;
			float4 _RampTex_ST;

			fixed4 _Color;
			fixed4 _Specular;
			float _Gloss;

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 worldPos : TEXCOORD0;
				float2 uv : TEXCOORD1;
				float rampUV : TEXCOORD2;
				float3 worldNormal : TEXCOORD3;
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.rampUV = TRANSFORM_TEX(v.uv, _RampTex);

				o.worldPos = mul(UNITY_MATRIX_M, v.vertex);
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				float3 worldNormal = normalize(i.worldNormal);
				float3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
				float3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				
				fixed3 albedo = _Color.rgb*tex2D(_MainTex, i.uv);
				
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz*albedo;

				float halfLambert = dot(worldNormal, worldLightDir)*0.5 + 0.5;
				fixed3 diffuse = _LightColor0 * tex2D(_RampTex, fixed2(halfLambert, 0))*albedo;

				float3 halfViewLight = normalize(worldViewDir + worldLightDir);
				fixed3 specular = _LightColor0.rgb*_Specular*pow(max(0, dot(halfViewLight, worldNormal)), _Gloss);

				return fixed4(ambient + diffuse + specular, 1);
			}
			ENDCG
		}
	}
}
