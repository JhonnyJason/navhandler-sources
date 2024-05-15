############################################################
pageloadAction = {
    action: "pageload"
    timestamp: Date.now()
}

############################################################
NAV_info = {
    lastNavAction: pageloadAction
}

############################################################
navState = {}

############################################################
rootState = {
    base: "RootState"
    modifier: "none"
    context: null
    depth: 0
    navAction: null
}

############################################################
backNavPromiseResolve = null
backNavPromiseTimestamp = null

navigationLocked = true

loadAppWithNavState = () -> return
updateAppWithNavState = () -> return



############################################################
debugFrame = """
<div id="NAVDEBUG-navstate-container" style="
    position: absolute;
    z-index: 9999;
    left: 0;
    top: 50%;
    transform: translateY(-50%);
    padding: 5px;
    height: fit-content;
    width: fit-content;
    box-sizing: border-box;
    color: #000;
    text-align: left;
    background-color: #fffa;
    border: solid 2px blue;
    font-size: 12px;
">
    <h1 style="
        font-size: 14px;
        font-weight: bold;
        padding: 0;
        margin: 0;
    ">NavState:</h1>
    <div id="NAVDEBUG-navstatedisplay" style="
        white-space: pre-wrap;
        line-height: 130%;
    "></div>
</div>
"""

debugMode = false
navstatedisplay = null

############################################################
export initialize = (onLoad, onUpdate, debug) ->
    if typeof onLoad == "function" then loadAppWithNavState = onLoad
    if typeof onUpdate == "function" then updateAppWithNavState = onUpdate
    
    window.addEventListener("popstate", historyStateChanged)
    
    info = sessionStorage.getItem("NAV_info")
    if !info? then storeNavInfo(NAV_info)
    
    NAV_info = JSON.parse(sessionStorage.getItem("NAV_info"))
    
    navigationLocked = false

    if debug
        debugMode = true
        document.body.insertAdjacentHTML('beforeend', debugFrame)
        navstatedisplay = document.getElementById("NAVDEBUG-navstatedisplay")
    return

############################################################
export appLoaded = ->
    return if navigationLocked

    if !isValidHistoryState() 
        ## This is the very first appload    
        rootState.navAction = pageloadAction
        NAV_info.lastNavAction = rootState.navAction
        storeNavInfo(NAV_info)
        
        history.replaceState(rootState, "")
    else
        ## we must've done some kind of refresh
        navState = history.state
        navState.navAction = getBrowserNavAction()
        NAV_info.lastNavAction = navState.navAction
        storeNavInfo(NAV_info)        
        
        history.replaceState(navState, "")

    # if navState.base == "VOID"
    #     try
    #         navigationLocked = true
    #         await navigateBack(1)
    #     finally navigationLocked = false

    await escapeVoidState() # we might be in state "VOID" -> escape it!

    navState = history.state
    displayState(navState)
    loadAppWithNavState(navState)
    return

############################################################
historyStateChanged = (evnt) ->
    ## Assumption: this only happens on:
    #    - Browser Refresh
    #    - Browser Forward
    #    - Browser Back 
    #    - Code Back -> only this is interesting to us

    # Exception: changing the URL and click enter
    if !isValidHistoryState() then return appLoaded() ## we treat it as appload for now :-)
        # newNavStateString = JSON.stringify(history.state)
        # oldNavStateString = JSON.stringify(navState)

        # if isValidState(navState) ## treat it as refresh
        #     navState.navAction = getBrowserNavAction()
        #     NAV_info.lastNavAction = navState.navAction
        #     storeNavInfo(NAV_info)
            
        #     history.replaceState(navState, "")

        # else ## What to do with this? treat it as pageLoad event?
        #     console.warn("No Valid History State on popstateEvent!\n New history State:#{newNavStateString}\n Last history State:#{oldNavStateString}") 
        #     return appLoaded()

    navState = history.state
    internalBackNav = isInternalBackNavAction(NAV_info.lastNavAction)
    
    if internalBackNav then navState.navAction = NAV_info.lastNavAction
    else navState.navAction = getBrowserNavAction()
    
    history.replaceState(navState, "")
    displayState(navState)
    
    if internalBackNav then resolveInternalBackNav()
    else if navState.base != "VOID" then updateAppWithNavState(navState)
    return


############################################################
escapeVoidState = ->
    ## If we are in VOID state then we go back one step
    if navState.base == "VOID"
        try
            navigationLocked = true
            await navigateBack(1)
        finally navigationLocked = false
    return 

############################################################
#region Helper Functions

############################################################
updateNavState = (base, modifier, context, navAction) ->
    navState.base = base
    navState.modifier = modifier
    navState.context = context || null
    navState.navAction = navAction
    return

############################################################
#region Navigation Methods
navigateTo = (base, modifier, context) ->
    navAction = getNavAction()
    updateNavState(base, modifier, context, navAction)
    navState.depth = navState.depth + 1

    NAV_info.lastNavAction = navAction
    storeNavInfo(NAV_info)        

    history.pushState(navState, "")
    displayState(navState)
    return

navReplace = (base, modifier, context) ->
    navAction = getNavAction()
    updateNavState(base, modifier, context, navAction)
    
    NAV_info.lastNavAction = navAction
    storeNavInfo(NAV_info)       

    history.replaceState(navState, "")
    displayState(navState)
    return

navigateBack = (steps) ->
    return if backNavPromiseResolve?
    return if navState.depth == 0 or steps > navState.depth

    navAction = getBackNavAction()

    NAV_info.lastNavAction = navAction
    storeNavInfo(NAV_info)        

    backNavPromise = createBackNavPromise(navAction)
    ## Back navigation sets "navState" by popstate event
    history.go(-steps)

    return backNavPromise

############################################################
clearNavTree = ->
    await navigateBack(navState.depth)
    navigateTo("VOID", "none")
    await navigateBack(1)
    return

#endregion

############################################################
#region Backwards Navigation Helpers
isInternalBackNavAction = (navAction) ->
    if navAction.action != "back" then return false
    if navAction.timestamp != backNavPromiseTimestamp then return false
    return true

createBackNavPromise = (navAction) ->
    backNavPromiseTimestamp = navAction.timestamp
    pConstruct = (resolve) -> backNavPromiseResolve = resolve
    return new Promise(pConstruct)

resolveInternalBackNav = ->
    backNavPromiseResolve()
    backNavPromiseResolve = null
    backNavPromiseTimestamp = null 
    return

#endregion

############################################################
#region NavAction Objects
getBrowserNavAction = ->
    return {
        action: "browserNav {refresh, back or forward}"
        timestamp: Date.now()
    }

getNavAction = ->
    return {
        action: "nav"
        timestamp: Date.now()
    }

getBackNavAction = ->
    return {
        action: "back"
        timestamp: Date.now()
    }

#endregion

############################################################
isValidHistoryState = -> isValidState(history.state)

isValidState = (state) ->
    if !state? then return false
    stateKeys = Object.keys(state)
    validKeys = Object.keys(rootState)
    if stateKeys.length != validKeys.length then return false

    for sKey,idx in stateKeys
        if sKey != validKeys[idx] then return false
    return true


############################################################
storeNavInfo = (info) -> sessionStorage.setItem("NAV_info", JSON.stringify(info))

############################################################
displayState = (state) ->
    return unless navstatedisplay?
    stateString = JSON.stringify(state, null, 4)
    navstatedisplay.innerHTML = stateString
    return

#endregion

############################################################
#region Public Navigation Functions
export toMod = (newMod, context) ->
    return if navigationLocked
    if !newMod? then newMod = "none"
    if typeof newMod != "string" then throw new Error("In navhandler.toMod `newMod` is not a string!")

    await escapeVoidState()
    oldMod = navState.modifier

    ## We need to merge the context, as the baseState context is still important
    if typeof context == "object" then Object.assign(context, navState.context)
    else context = navState.context

    ## case 0 - oldMod is newMod 
    if oldMod == newMod
        ## Nothing to be done :-)
        ## Maybe merge ne context?
        return

    ## case 1 - oldMod is "none" newMod is not "none"
    if oldMod == "none" and newMod != "none"
        ## regular state navigation to state with the modifier
        navigateTo(navState.base, newMod, context)
        updateAppWithNavState(navState)
        return

    ## case 2 - oldMod is not "none" newMod is "none"
    if oldMod != "none" and newMod == "none"
        ## navigate back 1 step
        try
            navigationLocked = true
            await navigateBack(1)
        finally navigationLocked = false
        
        updateAppWithNavState(navState)
        return

    ## case 3 - oldMod is not "none" newMod is different
    if oldMod != "none"
        ## replace state with new State
        navReplace(navState.base, newMod, context)
        updateAppWithNavState(navState)
        return

    return

export toBase = (newBase, context) ->
    return if navigationLocked
    if typeof newBase != "string" then throw new Error("In navhandler.toBase `newBase` must a string!")

    await escapeVoidState()
    oldBase = navState.base
    oldMod = navState.modifier

    ## If we already have the same base state then we can replace that state
    if oldBase == newBase 
        if oldMod == "none"
            navReplace(newBase, "none", context)
            updateAppWithNavState(navState)
            return

        ## If we have some modifier on, then we need to go back one and replace that state
        try
            navigationLocked = true
            await navigateBack(1)
            navReplace(newBase, "none", context)
        finally navigationLocked = false

        updateAppWithNavState(navState)
        return

    ## When oldBase != newBase
    if oldMod == "none" 
        navigateTo(newBase, oldMod, context)
        updateAppWithNavState(navState)
        return

    ## If we have some modifier on, then we need to replace the current state
    navReplace(newBase, "none", context)
    updateAppWithNavState(navState)
    return

export toBaseAt = (newBase, context, depth) ->
    return if navigationLocked

    oldMod = navState.modifier
    oldDepth = navState.depth

    if typeof newBase != "string" then throw new Error("In navhandler.toBase `newBase` must a string!")
    if typeof depth != "number" then throw new Error("Depth must be specified, and be a number!")
    if depth == 0 then throw new Error("Depth cannot be 0!")
    if depth == (oldDepth + 1) then return toBase(newBase, context) ## when we want it as next state we can directly navigate to there
    if depth > oldDepth then throw new Error("Our current depth is before the the newly specified depth. We don't dare to jump unto the unknown future!")

    ## To cancel all future history we go back 1 step before the specified depth
    ## then we navigate into the desired state.
    backSteps = oldDepth - depth + 1
    try
        navigationLocked = true
        await navigateBack(backSteps)
        navigateTo(newBase, "none", context)
    finally navigationLocked = false

    updateAppWithNavState(navState)
    return

############################################################
export toRoot = (clear) ->
    return if navigationLocked

    try
        navigationLocked = true
        if clear? and clear then await clearNavTree()
        else await navigateBack(navState.depth)
    finally navigationLocked = false

    updateAppWithNavState(navState)
    return


export back = (steps) ->
    return if navigationLocked

    try 
        navigationLocked = true
        if !steps? then await navigateBack(1)
        else if typeof steps != "number" then throw new Error("In navhandler.back `steps` is not a number!")
        else await navigateBack(steps)
    finally navigationLocked = false

    updateAppWithNavState(navState)
    return
    

#endregion