//
//  Schermo.metal
//  Fovea — By D.S.
//
//  Algoritmo Eye-Shield (Tang & Shin, USENIX Security 2023), applicato in
//  tempo reale a qualsiasi vista SwiftUI tramite layerEffect (iOS 17+).
//
//  L'idea: metà dei pixel resta com'è, l'altra metà — quelli neri della
//  scacchiera — riceve il "complemento", cioè il valore che, mediato col
//  vicino, restituisce esattamente la versione sfocata.
//
//      complemento = 2·targ² − img²
//      media(img², complemento²) = targ²
//
//  Da vicino l'occhio separa le due celle e vede il contenuto originale.
//  Oltre la distanza di risoluzione le celle si fondono e resta solo targ,
//  la versione sfocata. Non "un po' meno nitido": proprio la sfocatura.
//
//  I tre punti in cui la mia versione a righe sbagliava:
//
//  1. La media va fatta in luce LINEARE, non in sRGB. Per questo si lavora
//     sui quadrati e si chiude con una radice: l'occhio somma fotoni, non
//     valori di byte. Mediando in sRGB il trucco si indebolisce e basta.
//  2. Scacchiera, non righe verticali. Le righe degradano solo la
//     risoluzione orizzontale; la scacchiera è isotropa e funziona anche se
//     guardi il telefono ruotato.
//  3. Il bersaglio è la versione SFOCATA, non un grigio uniforme. Così il
//     contenuto da lontano sembra ancora qualcosa — solo illeggibile — e
//     non un rettangolo piatto che grida "qui c'è qualcosa di nascosto".
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

    // Bersaglio: media locale 3×3. È la "versione sfocata" dell'algoritmo,
    // calcolata al volo invece di tenere un secondo buffer in memoria.
    half4 somma = 0.0h;
    for (int j = -1; j <= 1; ++j) {
        for (int i = -1; i <= 1; ++i) {
            somma += strato.sample(posizione + float2(float(i) * raggio,
                                                      float(j) * raggio));
        }
    }
    half4 targ = somma / 9.0h;

    // Scacchiera nelle coordinate dello strato.
    float2 c = floor(posizione / max(cella, 0.05));
    bool complementare = (fmod(c.x + c.y, 2.0) >= 1.0);

    half3 i2 = img.rgb * img.rgb;
    half3 t2 = targ.rgb * targ.rgb;

    // Il clamp a zero serve: dove il contrasto locale è forte, 2t²−i² può
    // andare sotto zero e la radice esploderebbe.
    half3 complemento = sqrt(max(2.0h * t2 - i2, 0.0h));

    half3 protetto = complementare ? complemento : img.rgb;

    // forza 0 = originale, 1 = protezione piena. Serve a farla salire con
    // una dissolvenza invece che di scatto.
    protetto = mix(img.rgb, protetto, half(clamp(forza, 0.0, 1.0)));

    return half4(protetto, img.a);
}
