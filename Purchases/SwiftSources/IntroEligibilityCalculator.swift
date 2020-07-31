//
//  IntroEligibilityCalculator.swift
//  Purchases
//
//  Created by Andrés Boedo on 7/14/20.
//  Copyright © 2020 Purchases. All rights reserved.
//

import Foundation
import StoreKit

public class IntroEligibilityCalculator: NSObject {
    private let productsManager: ProductsManager
    private let receiptParser: ReceiptParser
    
    public override init() {
        self.productsManager = ProductsManager()
        self.receiptParser = ReceiptParser()
    }
    
    internal init(productsManager: ProductsManager,
                  receiptParser: ReceiptParser) {
        self.productsManager = productsManager
        self.receiptParser = receiptParser
    }
    
    @available(iOS 12.0, macOS 10.14, macCatalyst 13.0, tvOS 12.0, watchOS 6.2, *)
    @objc public func checkTrialOrIntroductoryPriceEligibility(withData receiptData: Data,
                                                               productIdentifiers candidateProductIdentifiers: Set<String>,
                                                               completion: @escaping ([String: Int], Error?) -> Void) {
        guard candidateProductIdentifiers.count > 0 else {
            completion([:], nil)
            return
        }
        
        var result: [String: Int] = candidateProductIdentifiers.reduce(into: [:]) { resultDict, productId in
            resultDict[productId] = IntroEligibilityStatus.unknown.rawValue
        }
        let receipt = receiptParser.parse(from: receiptData)
        let purchasedProductIdsWithIntroOffers = receipt.purchasedIntroOfferProductIdentifiers()
        
        let allProductIdentifiers = candidateProductIdentifiers.union(purchasedProductIdsWithIntroOffers)
        
        productsManager.products(withIdentifiers: allProductIdentifiers) { allProducts in
            let purchasedProductsWithIntroOffers = allProducts.filter { purchasedProductIdsWithIntroOffers.contains($0.productIdentifier) }
            let candidateProducts = allProducts.filter { candidateProductIdentifiers.contains($0.productIdentifier) }
            
            let eligibility: [String: Int] = self.checkIntroEligibility(candidateProducts: candidateProducts,
                                                                        purchasedProductsWithIntroOffers: purchasedProductsWithIntroOffers)
            result.merge(eligibility) { (_, new) in new }
            
            completion(result, nil)
        }
    }
}

@available(iOS 12.0, macOS 10.14, macCatalyst 13.0, tvOS 12.0, watchOS 6.2, *)
private extension IntroEligibilityCalculator {
    
    func checkIntroEligibility(candidateProducts: Set<SKProduct>,
                               purchasedProductsWithIntroOffers: Set<SKProduct>) -> [String: Int] {
        var result: [String: Int] = [:]
        for candidate in candidateProducts {
            let usedIntroForProductIdentifier = purchasedProductsWithIntroOffers
                .contains { purchased in
                    let foundByProductId = candidate.productIdentifier == purchased.productIdentifier
                    let foundByGroupId = candidate.subscriptionGroupIdentifier == purchased.subscriptionGroupIdentifier
                        && candidate.subscriptionGroupIdentifier != nil
                    return foundByProductId || foundByGroupId
                }
            result[candidate.productIdentifier] = usedIntroForProductIdentifier
                ? IntroEligibilityStatus.ineligible.rawValue
                : IntroEligibilityStatus.eligible.rawValue
        }
        return result
    }
}

internal enum IntroEligibilityStatus: Int {
    case unknown,
         ineligible,
         eligible
}
