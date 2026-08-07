//
//  SafariWebExtensionHandler.swift
//  Fovea Safari — By D.S.
//
//  Ponte nativo. Angolo, lente e soglia vivono interamente nel content
//  script: qui non passa contenuto delle pagine, mai.
//
//  L'unica cosa che fa: scrivere un timestamp nell'App Group. È così che la
//  pagina ATTIVA dell'app sa che l'estensione è davvero accesa, invece di
//  presumerlo. Su iOS non esiste API per interrogare lo stato di una
//  Safari Extension, quindi è l'estensione stessa a farsi viva.
//

import SafariServices

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    private static let gruppo = "group.com.byds.fovea"
    private static let chiave = "estensione.ultimoAvvio"

    func beginRequest(with context: NSExtensionContext) {
        UserDefaults(suiteName: Self.gruppo)?
            .set(Date(), forKey: Self.chiave)

        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: ["stato": "ok"]]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}
