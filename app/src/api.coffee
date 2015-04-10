class @Api

  @init: ->
    @_has_session = false
    ledger.app.on 'dongle:unlocked', ->
      Api._has_session = true

  @listener: (event) ->
    data = event.data
    switch data.command
      when 'has_session'
        @hasSession(data)
      when 'bitid'
        @bitid(data)
      when  'send_payment'
        @sendPayment(data)
      when 'sign_message'
        @signMessage(data)
      when 'cosign_transaction'
        @cosignTransaction(data)

  @hasSession: (data) ->
    chrome.runtime.sendMessage {
      command: 'has_session',
      success: @_has_session
    }    

  @sendPayment: (data) ->
    ledger.app.router.go '/wallet/send/index', {address: data.address, amount: data.amount}

  @signMessage: (data) ->
    try
      ledger.bitcoin.bitid.getAddress path: data.path
      .then (result) =>
        @address = result.bitcoinAddress.value
        ledger.bitcoin.bitid.signMessage(data.message, path: data.path)
        .then (result) =>
          @callback_success('sign_message', signature: result, address: @address)
          return
        .fail (error) =>
          @callback_cancel('sign_message', JSON.stringify(error))
          return
      .fail (error) =>
        @callback_cancel('sign_message', JSON.stringify(error))
        return
    catch error
      callback_cancel('sign_message', JSON.stringify(error))

  @cosignTransaction: (data) ->
    try
      transaction = Bitcoin.Transaction.deserialize(data.transaction);
      ledger.app.dongle._btchip.signP2SHTransaction_async(data.inputs, transaction, data.scripts, data.path)
      .then (result) =>
        @callback_success('cosign_transaction', signatures: result)
        return
      .fail (error) =>
        @callback_cancel('cosign_transaction', JSON.stringify(error))
        return
    catch error
      @callback_cancel('cosign_transaction', JSON.stringify(error))

  @bitid: (data) ->
    ledger.app.router.go '/wallet/bitid/index', {uri: data.uri, silent: data.silent}

  @callback_cancel: (command, message) ->
    chrome.runtime.sendMessage 
      command: command,
      success: false,
      message: message

  @callback_success: (command, data) ->
    chrome.runtime.sendMessage $.extend {
        command: command,
        success: true 
      }, data