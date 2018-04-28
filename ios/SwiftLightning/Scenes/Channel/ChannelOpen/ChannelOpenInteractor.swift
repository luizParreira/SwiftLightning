//
//  ChannelOpenInteractor.swift
//  SwiftLightning
//
//  Created by Howard Lee on 2018-04-23.
//  Copyright (c) 2018 BiscottiGelato. All rights reserved.
//
//  This file was generated by the Clean Swift Xcode Templates so
//  you can apply clean architecture to your iOS and Mac projects,
//  see http://clean-swift.com
//

import UIKit

protocol ChannelOpenBusinessLogic
{
  func channelConfirm(request: ChannelOpen.ChannelConfirm.Request)
  func validateNodePubKey(request: ChannelOpen.ValidateNodePubKey.Request)
  func validateNodeIPPort(request: ChannelOpen.ValidateNodeIPPort.Request)
  func validateAmounts(request: ChannelOpen.ValidateAmounts.Request)
  func getOnChainConfirmedBalance(request: ChannelOpen.GetBalance.Request)
}

protocol ChannelOpenDataStore
{
  var nodePubKey: String { get }
  var nodeIP: String { get }
  var nodePort: Int { get }
  var fundingAmt: Bitcoin { get }
  var initPayAmt: Bitcoin { get }
  var confSpeed: OnChainConfirmSpeed { get }
}

class ChannelOpenInteractor: ChannelOpenBusinessLogic, ChannelOpenDataStore {
  
  var presenter: ChannelOpenPresentationLogic?
  var worker: ChannelOpenWorker?
  
  
  // MARK: Data Store
  
  private var _nodePubKey: String?
  private var _nodeIP: String?
  private var _nodePort: Int?
  private var _fundingAmt: Bitcoin?
  private var _initPayAmt: Bitcoin?
  private var _confSpeed: OnChainConfirmSpeed?
  
  var nodePubKey: String {
    guard let returnValue = _nodePubKey else {
      SLLog.fatal("nodePubKey in Data Store = nil")
    }
    return returnValue
  }
  
  var nodeIP: String {
    guard let returnValue = _nodeIP else {
      SLLog.fatal("nodeIP in Data Store = nil")
    }
    return returnValue
  }
  
  var nodePort: Int {
    guard let returnValue = _nodePort else {
      SLLog.fatal("nodePort in Data Store = nil")
    }
    return returnValue
  }
  
  var fundingAmt: Bitcoin {
    guard let returnValue = _fundingAmt else {
      SLLog.fatal("fundingAmt in Data Store = nil")
    }
    return returnValue
  }
  
  var initPayAmt: Bitcoin {
    guard let returnValue = _initPayAmt else {
      SLLog.fatal("initPayAmt in Data Store = nil")
    }
    return returnValue
  }
  
  var confSpeed: OnChainConfirmSpeed {
    guard let returnValue = _confSpeed else {
      SLLog.fatal("confSpeed in Data Store = nil")
    }
    return returnValue
  }
  
  
  // MARK: On Chain Confirmed Balance
  
  func getOnChainConfirmedBalance(request: ChannelOpen.GetBalance.Request) {
    LNServices.walletBalance { (responder) in
      do {
        let balance = try responder()
        let response = ChannelOpen.GetBalance.Response(onChainBalance: Bitcoin(inSatoshi: balance.confirmed))
        self.presenter?.presentOnChainConfirmedBalance(response: response)
      } catch {
        let response = ChannelOpen.GetBalance.Response(onChainBalance: nil)
        self.presenter?.presentOnChainConfirmedBalance(response: response)
      }
    }
  }
  
  
  // MARK: Validate Entries
  
  func validateNodePubKey(request: ChannelOpen.ValidateNodePubKey.Request) {
    let isNodePubKeyValid = LNManager.validateNodePubKey(request.nodePubKey)
    let response = ChannelOpen.ValidateNodePubKey.Response(isKeyValid: isNodePubKeyValid)
    presenter?.presentNodePubKeyValid(response: response)
  }
  
  func validateNodeIPPort(request: ChannelOpen.ValidateNodeIPPort.Request) {
    let ipPort = LNManager.parsePortIPString(request.nodeIPPort)
    let isNodeIPValid = ipPort.ipString != nil
    let isNodePortValid = ipPort.port != nil
    let response = ChannelOpen.ValidateNodeIPPort.Response(isIPValid: isNodeIPValid,
                                                           isPortValid: isNodePortValid)
    presenter?.presentNodePortIPValid(response: response)
  }
  
  func validateAmounts(request: ChannelOpen.ValidateAmounts.Request) {
    // TODO: Calculate Fee involved for desired Conf Speed
    
    LNServices.walletBalance { (responder) in
      do {
        let balanceInSat = try responder()
        
        var fundingError: ChannelOpen.ValidateAmounts.Error? = nil
        var initPayError: ChannelOpen.ValidateAmounts.Error? = nil
        
        // TODO: Need to know what the text field value means. Satoshi? Bits? USD? etc
        guard let fundingAmt = Bitcoin(inSatoshi: request.fundingAmt) else {
          let response = ChannelOpen.ValidateAmounts.Response(fundingError: ChannelOpen.ValidateAmounts.Error.invalid,
                                                              initPayError: nil)
          self.presenter?.presentAmountValid(response: response)
          return
        }
      
        if fundingAmt.integerInSatoshis > balanceInSat.confirmed {
          fundingError = ChannelOpen.ValidateAmounts.Error.insufficient
        }
        
        guard let initPayAmt = Bitcoin(inSatoshi: request.initPayAmt) else {
          let response = ChannelOpen.ValidateAmounts.Response(fundingError: fundingError,
                                                              initPayError: ChannelOpen.ValidateAmounts.Error.invalid)
          self.presenter?.presentAmountValid(response: response)
          return
        }
        
        if initPayAmt > fundingAmt {
          initPayError = ChannelOpen.ValidateAmounts.Error.insufficient
        }
        
        let response = ChannelOpen.ValidateAmounts.Response(fundingError: fundingError,
                                                            initPayError: initPayError)
        self.presenter?.presentAmountValid(response: response)
        
      } catch {
        let response = ChannelOpen.ValidateAmounts.Response(fundingError: ChannelOpen.ValidateAmounts.Error.walletBalance,
                                                            initPayError: ChannelOpen.ValidateAmounts.Error.walletBalance)
        self.presenter?.presentAmountValid(response: response)
      }
    }
  }
  
  
  // MARK: Channel Opening Confirm
  
  func channelConfirm(request: ChannelOpen.ChannelConfirm.Request)
  {
    // Validate and Convert Node Pub Key
    let isNodePubKeyValid = LNManager.validateNodePubKey(request.nodePubKey)
    _nodePubKey = request.nodePubKey
    
    // Validate and Convert Port IP
    let ipPort = LNManager.parsePortIPString(request.nodeIPPort)
    _nodeIP = ipPort.ipString
    _nodePort = ipPort.port
    let isNodeIPValid = _nodeIP != nil
    let isNodePortValid = _nodePort != nil
    
    // TODO: Calculate Fee involved for desired Conf Speed
    _confSpeed = request.confSpeed
    
    // Validate and Convert Funding Amount
    var isFundingAmtValid = false
    
    // TODO: Need to know what the text field value means. Satoshi? Bits? USD? etc
    if let fundingAmt = Bitcoin(inSatoshi: request.fundingAmt) {
      _fundingAmt = fundingAmt
      isFundingAmtValid = true
    }
    
    // TODO: Check for sufficient on-chain funds
    
    // Validate and Convert Initial Payment
    var isInitPayAmtValid = false
    
    // TODO: Need to know what the text field value means. Satoshi? Bits? USD? etc
    if let initPayAmt = Bitcoin(inSatoshi: request.initPayAmt), initPayAmt <= fundingAmt {
      _initPayAmt = initPayAmt
      isInitPayAmtValid = true
    }
    
    // Store to DataStore if A-OK
    if !(isNodePubKeyValid && isNodeIPValid && isNodePortValid && isFundingAmtValid && isInitPayAmtValid) {
      _nodePubKey = nil
      _nodeIP = nil
      _nodePort = nil
      _fundingAmt = nil
      _initPayAmt = nil
    }
    
    // Report field valid status to Presenter
    let response = ChannelOpen.ChannelConfirm.Response(isPubKeyValid: isNodePubKeyValid,
                                                       isIPValid: isNodeIPValid,
                                                       isPortValid: isNodePortValid,
                                                       isFundingValid: isFundingAmtValid,
                                                       isInitPayValid: isInitPayAmtValid)
    presenter?.presentChannelConfirm(response: response)
  }
}
