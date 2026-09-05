package com.kamilunavo.schonerledigt

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import kotlinx.coroutines.flow.MutableStateFlow

data class BillingState(val ready: Boolean = false, val pro: Boolean = false, val yearly: ProductDetails? = null, val lifetime: ProductDetails? = null, val error: String? = null)

class BillingManager(context: Context) {
    companion object {
        const val YEARLY = "com.kamilunavo.schonerledigt.pro.yearly"
        const val LIFETIME = "com.kamilunavo.schonerledigt.pro.lifetime"
    }
    val state = MutableStateFlow(BillingState())
    private lateinit var client: BillingClient

    init {
        client = BillingClient.newBuilder(context)
            .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
            .setListener { result, purchases ->
                if (result.responseCode == BillingClient.BillingResponseCode.OK && purchases != null) {
                    purchases.forEach { purchase ->
                        if (purchase.purchaseState == com.android.billingclient.api.Purchase.PurchaseState.PURCHASED) {
                            state.value = state.value.copy(pro = true)
                            if (!purchase.isAcknowledged) {
                                client.acknowledgePurchase(
                                    AcknowledgePurchaseParams.newBuilder()
                                        .setPurchaseToken(purchase.purchaseToken)
                                        .build()
                                ) {}
                            }
                        }
                    }
                }
            }
            .build()
        connect()
    }
    private fun connect() = client.startConnection(object : BillingClientStateListener {
        override fun onBillingServiceDisconnected() { state.value = state.value.copy(ready = false) }
        override fun onBillingSetupFinished(result: BillingResult) { if (result.responseCode == BillingClient.BillingResponseCode.OK) { state.value = state.value.copy(ready = true); loadProducts(); restore() } }
    })
    private fun loadProducts() {
        val items = listOf(
            QueryProductDetailsParams.Product.newBuilder().setProductId(YEARLY).setProductType(BillingClient.ProductType.SUBS).build(),
            QueryProductDetailsParams.Product.newBuilder().setProductId(LIFETIME).setProductType(BillingClient.ProductType.INAPP).build()
        )
        client.queryProductDetailsAsync(QueryProductDetailsParams.newBuilder().setProductList(items).build()) { result, products ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) state.value = state.value.copy(yearly = products.productDetailsList.firstOrNull { it.productId == YEARLY }, lifetime = products.productDetailsList.firstOrNull { it.productId == LIFETIME })
        }
    }
    fun purchase(activity: Activity, product: ProductDetails) {
        val builder = BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(product)
        product.subscriptionOfferDetails?.firstOrNull()?.offerToken?.let(builder::setOfferToken)
        client.launchBillingFlow(activity, BillingFlowParams.newBuilder().setProductDetailsParamsList(listOf(builder.build())).build())
    }
    fun restore() {
        listOf(BillingClient.ProductType.SUBS, BillingClient.ProductType.INAPP).forEach { type -> client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(type).build()) { _, purchases -> if (purchases.any { it.purchaseState == com.android.billingclient.api.Purchase.PurchaseState.PURCHASED }) state.value = state.value.copy(pro = true) } }
    }
}
