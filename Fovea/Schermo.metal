//
//  Schermo.metal
//  Fovea — By D.S.
//
//  Algoritmo Eye-Shield (Tang & Shin, USENIX Security 2023).
//
//      complemento = 2·targ² − img²      con targ = versione SFOCATA
//      media(img², complemento²) = targ²
//
//  Da vicino l'occhio separa le celle e legge l'originale. Oltre la distanza
//  di risoluzione si mediano e resta targ, cioè la sfocatura.
//
//  ERRORE DELLA PRIMA VERSIONE, corretto qui: il raggio della sfocatura era
//  legato alla dimensione della cella. Con celle da 1 punto il bersaglio
//  veniva calcolato su ±1 punto, quindi targ ≈ img, quindi complemento ≈ img:
//  la scacchiera esisteva ma con due valori identici. Effetto zero.
//  I due parametri ora sono indipendenti — cella piccola, sfocatura larga.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

[[stitchable]] half4 fovea(float2 posizione,
                           SwiftUI::Layer strato,
                           float cella,
                           float raggio,
                           float forza)
{
    half4 img = strato.sample(posizione);

    if (forza <= 0.001) {
        return img;
    }

    // Bersaglio: sfocatura vera, 5×5 campioni su tutto il raggio.
    // È questa larghezza a creare la differenza fra img e targ, e quindi
    // l'intera protezione.
    float passo = max(raggio, 1.0) * 0.5;
    half4 somma = 0.0h;
    for (int j = -2; j <= 2; ++j) {
        for (int i = -2; i <= 2; ++i) {
            somma += strato.sample(posizione + float2(float(i) * passo,
                                                      float(j) * passo));
        }
    }
    half4 targ = somma / 25.0h;

    // Scacchiera.
    float2 c = floor(posizione / max(cella, 0.05));
    bool complementare = (fmod(c.x + c.y, 2.0) >= 1.0);

    half3 i2 = img.rgb * img.rgb;
    half3 t2 = targ.rgb * targ.rgb;

    // Clamp obbligatorio: dove il contrasto locale è forte 2t²−i² va sotto
    // zero e la radice esploderebbe.
    half3 complemento = sqrt(max(2.0h * t2 - i2, 0.0h));

    half3 protetto = complementare ? complemento : img.rgb;
    protetto = mix(img.rgb, protetto, half(clamp(forza, 0.0, 1.0)));

    return half4(protetto, img.a);
}
