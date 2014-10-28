require = patchRequire global.require
init    = require("../common").init
utils   = require "utils.js"

deleteTestAccounts = ->
    casper.evaluate ->
        AccountStore  = require '../stores/account_store'
        account = AccountStore.getByLabel 'Test Account'
        if account?
            AccountActionCreator = require '../actions/account_action_creator'
            console.log "Deleting test account #{account.get 'id'}"
            AccountActionCreator.remove(account.get 'id')
        else
            console.log "No test account to delete"

#casper.test.tearDown deleteTestAccounts

casper.test.begin 'Test accounts', (test) ->
    init casper

    casper.start casper.cozy.startUrl, ->
        accountSel = "#account-list .menu-item.account"
        test.assertExists accountSel, "Accounts in menu"

    casper.then ->
        accountSel = "#account-list .menu-item.account"
        accounts = casper.getElementsInfo accountSel
        casper.eachThen accounts, (response) ->
            account = response.data
            id = account.attributes['data-reactid']
            casper.click "[data-reactid='#{id}']"
            casper.waitForSelector ".active[data-reactid='#{id}']", ->
                label = casper.getElementInfo "[data-reactid='#{id}'] .item-label"
                test.pass "Account #{label.text} selected"
                if casper.exists ".message-list .message"
                    casper.click ".message-list .message a"
                    casper.waitUntilVisible ".conversation"
            , ->
                test.fail "Unable to select account #{account.text}"

    casper.run ->
        test.done()

casper.test.begin 'Create account', (test) ->
    init casper

    casper.start casper.cozy.startUrl, ->
        values =
            "account-type": "IMAP",
            "mailbox-email-address": "test@cozytest.org",
            "mailbox-imap-port": "993",
            "mailbox-imap-server": "toto",
            "mailbox-imap-ssl": true,
            "mailbox-imap-tls": false,
            "mailbox-label": "Test Account",
            "mailbox-name": "Test",
            "mailbox-password": "toto",
            "mailbox-smtp-port": "465",
            "mailbox-smtp-server": "toto",
            "mailbox-smtp-ssl": true,
            "mailbox-smtp-tls": false

        deleteTestAccounts()
        account = casper.evaluate ->
            AccountStore  = require '../stores/account_store'
            account = AccountStore.getByLabel 'Test Account'
            return account?
        test.assertFalsy account, "Test account doesnt exists"
        casper.click '#menu .new-account-action'
        casper.waitForSelector '#mailbox-config', ->
            test.assertSelectorHasText "#mailbox-config h3", "New account"
            test.assertDoesntExist "#mailbox-config .nav-tabs", "No tabs"
            test.assertSelectorHasText "#mailbox-config button", "Add", "Add button"
            test.assertDoesntExist "#mailbox-config .alert", "No error message"
            casper.click "#mailbox-config button"
            casper.waitForSelector "#mailbox-config .alert", ->
                test.pass "Error message displayed"
                test.assertElementCount ".form-group.has-error", 6, "Errors are underlined"
                casper.fillSelectors 'form', '#mailbox-label':  values['mailbox-label']
                casper.click "#mailbox-config button"
                casper.wait 100, ->
                    test.assertElementCount ".form-group.has-error", 5, "Errors are underlined"
                    casper.fillSelectors 'form',
                        '#mailbox-name': values['mailbox-name']
                        '#mailbox-email-address': values['mailbox-email-address']
                        '#mailbox-password': values['mailbox-password']
                        '#mailbox-smtp-server': values['mailbox-smtp-server']
                        '#mailbox-imap-server': values['mailbox-imap-server']
                        '#account-type': values['account-type']
                    casper.click "#mailbox-config button"
                    casper.waitWhileSelector "#mailbox-config .alert", ->
                        casper.waitForSelector "#mailbox-config .alert", ->
                            test.assertSelectorHasText "#mailbox-config button", "Add", "Wrong SMTP Server"
                            test.assertEquals casper.getFormValues('form'), values, "Form not changed"
                            test.assertDoesntExist ".has-error #mailbox-label", "No error on label"
                            test.assertExist ".has-error #mailbox-smtp-server", "Error on SMTP"
                            casper.fillSelectors 'form', '#account-type': 'TEST'
                            casper.wait 500, ->
                                casper.click "#mailbox-config button"
                                casper.waitForSelector "#mailbox-config .nav-tabs", ->
                                    test.pass 'No more errors ☺'

    casper.then ->
        test.comment "Creating mailbox"
        name = "Box 1"
        test.assertSelectorHasText "#mailbox-config .nav-tabs .active", "Folders", "Folders tab is active"
        test.assertDoesntExist ".form-group.draftMailbox .dropdown", "No draft folder"
        test.assertDoesntExist ".form-group.sentMailbox .dropdown",  "No sent folder"
        test.assertDoesntExist ".form-group.trashMailbox .dropdown", "No trash folder"
        test.assertElementCount "ul.boxes > li", 1, "No boxes"
        casper.fillSelectors 'form', '#newmailbox': name
        casper.click '.box.edited .box-action.add i'
        casper.waitForSelector '.box-item', ->
            test.assertSelectorHasText ".box .box-label", name, "Box created"
            test.assertExist ".form-group.draftMailbox .dropdown", "Draft folder", "Draft dropdown"
            test.assertSelectorHasText ".form-group.draftMailbox .dropdown-menu", name, "Box in draft dropdown"
            test.assertExist ".form-group.sentMailbox .dropdown",  "Sent folder", "Sent dropdown"
            test.assertSelectorHasText ".form-group.sentMailbox .dropdown-menu", name, "Box in sent dropdown"
            test.assertExist ".form-group.trashMailbox .dropdown", "Trash folder", "Trash dropdown"
            test.assertSelectorHasText ".form-group.trashMailbox .dropdown-menu", name, "Box in trash dropdown"

    casper.then ->
        test.comment "Rename mailbox"
        name = "Box 2"
        casper.click ".box .box-action.edit i"
        casper.waitForSelector ".box .box-action.save", ->
            casper.fillSelectors 'form', '.box .box-label': name
            casper.click ".box .box-action.save i"
            casper.waitForSelector ".box span.box-label", ->
                test.assertSelectorDoesntHaveText ".box .box-label", "Box 1", "Box renamed"
                test.assertSelectorHasText ".box .box-label", name, "Box renamed"
                test.assertExist ".form-group.draftMailbox .dropdown", "Draft folder", "Draft dropdown"
                test.assertSelectorHasText ".form-group.draftMailbox .dropdown-menu", name, "Box in draft dropdown"
                test.assertExist ".form-group.sentMailbox .dropdown",  "Sent folder", "Sent dropdown"
                test.assertSelectorHasText ".form-group.sentMailbox .dropdown-menu", name, "Box in sent dropdown"
                test.assertExist ".form-group.trashMailbox .dropdown", "Trash folder", "Trash dropdown"
                test.assertSelectorHasText ".form-group.trashMailbox .dropdown-menu", name, "Box in trash dropdown"

    casper.then ->
        test.comment "Delete mailbox"
        confirm = ''
        casper.evaluate ->
            window.cozytest = {}
            window.cozytest.confirm = window.confirm
            window.confirm = (txt) ->
                window.cozytest.confirmTxt = txt
                return true
        casper.click ".box .box-action.delete i"
        casper.waitFor ->
            confirm = casper.evaluate ->
                return window.cozytest.confirmTxt
            return confirm?
        , ->
            casper.echo "Alert received: " + confirm
            casper.waitWhileSelector "ul.boxes .box span.box-label", ->
                test.assert (confirm is "Do you really want to delete this box and everything in it ?"), "Confirmation dialog"
                test.assertDoesntExist ".form-group.draftMailbox .dropdown", "No draft folder"
                test.assertDoesntExist ".form-group.sentMailbox .dropdown",  "No sent folder"
                test.assertDoesntExist ".form-group.trashMailbox .dropdown", "No trash folder"
                test.assertElementCount "ul.boxes > li", 1, "No boxes"


    casper.then ->
        test.pass "ok"

    casper.run ->
        test.done()

casper.test.begin 'Test accounts', (test) ->
    init casper

    casper.start casper.cozy.startUrl, ->
        accountSel = "#account-list .menu-item.account"
        accounts = casper.getElementsInfo accountSel
        id = accounts[0].attributes['data-reactid']
        casper.click "[data-reactid='#{id}']"
        casper.waitForSelector ".active[data-reactid='#{id}']", ->
            casper.click '#quick-actions .mailbox-config'
            casper.waitForSelector '#mailbox-config', ->
                test.assertSelectorHasText "#mailbox-config h3", "Edit account"
                test.assertSelectorHasText "#mailbox-config .nav-tabs .active", "Account", "Account tab is active"
                test.assertSelectorHasText "#mailbox-config .nav-tabs", "Folders", "Folder tab visible"


    casper.run ->
        test.done()
