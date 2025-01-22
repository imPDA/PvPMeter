local addon = {}

addon.name = 'IPM_MENU'
addon.display_name = 'PvP Meter'

local Log = IPM_Log

local LMM = LibMainMenu2
LMM:Init()

local CATEGORIES = {
	{
		name = 'Battlegrounds',
		container = IPM_BGs_Container,
		icons = {
			normal = 'EsoUI/Art/Battlegrounds/battlegrounds_tabIcon_battlegrounds_up.dds',
			pressed = 'EsoUI/Art/Battlegrounds/battlegrounds_tabIcon_battlegrounds_down.dds',
			highlight = 'EsoUI/Art/Battlegrounds/battlegrounds_tabIcon_battlegrounds_over.dds',
		},
	},
	{
		name = 'Duels',
		container = IPM_Duels_Container,
		icons = {
			normal = "EsoUI/Art/Journal/journal_tabIcon_leaderboard_up.dds",
			pressed = "EsoUI/Art/Journal/journal_tabIcon_leaderboard_down.dds",
			highlight = "EsoUI/Art/Journal/journal_tabIcon_leaderboard_over.dds",
		},
	},
	{
		name = 'TOT',
		container = IPM_TOT_Container,
		icons = {
			normal = 'EsoUI/Art/Tribute/tribute_tabicon_tribute_up.dds',
			pressed = 'EsoUI/Art/Tribute/tribute_tabicon_tribute_down.dds',
			highlight = 'EsoUI/Art/Tribute/tribute_tabicon_tribute_over.dds',
		},
	}
}

function addon:Initialize(initBGs, initDuels, initTOT)
	ZO_CreateStringId('SI_IMP_PVP_METER_MAIN_MENU_TITLE', addon.display_name)

	local IPM_TITLE_FRAGMENT = ZO_SetTitleFragment:New(SI_IMP_PVP_METER_MAIN_MENU_TITLE)
	-- TODO: subtitle

	local SUBMENU = {}
	local SCENES = {}

    local RIGHT_PANEL = ZO_FadeSceneFragment:New(IPM_RightPanel)

	local function CreateScene(sceneName, container)
		local scene = ZO_Scene:New(sceneName, SCENE_MANAGER)

        scene:AddFragment(RIGHT_PANEL)

		scene:AddFragmentGroup(FRAGMENT_GROUP.PLAYER_PROGRESS_BAR_KEYBOARD_CURRENT)
		scene:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
		scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_STANDARD_RIGHT_PANEL)
		scene:AddFragment(RIGHT_BG_FRAGMENT)

		scene:AddFragment(TITLE_FRAGMENT)
		scene:AddFragment(IPM_TITLE_FRAGMENT)

		local fragment = ZO_FadeSceneFragment:New(container)
		scene:AddFragment(fragment)

		return scene
	end

	local function InitializeCategory(index)
		local category = CATEGORIES[index]
		local sceneName = addon.name .. category.name .. 'Scene'
		CreateScene(sceneName, category.container)
		table.insert(SUBMENU, {
			categoryName = category.name,
			descriptor = sceneName,
			normal = category.icons.normal,
			pressed = category.icons.pressed,
			highlight = category.icons.highlight,
		})
		table.insert(SCENES, sceneName)
	end

	local arg = {initBGs, initDuels, initTOT}
	for i, doInit in ipairs(arg) do
		if doInit then InitializeCategory(i) end
        Log('%s panel initialized', CATEGORIES[i].name)
	end

	local MENU_CATEGORY = {
		categoryName = SI_IMP_PVP_METER_MAIN_MENU_TITLE,
		binding = IPM_TOGGLE_PANEL,
		-- descriptor = 19,
		-- normal = 'EsoUi/Art/journal/journal_tabicon_achievements_up.dds',
		-- pressed = 'EsoUi/Art/journal/journal_tabicon_achievements_down.dds',
		-- highlight = 'EsoUi/Art/journal/journal_tabicon_achievements_over.dds',
		normal = 'EsoUi/Art/campaign/campaignbrowser_indexicon_normal_up.dds',
		pressed = 'EsoUi/Art/campaign/campaignbrowser_indexicon_normal_down.dds',
		highlight = 'EsoUi/Art/campaign/campaignbrowser_indexicon_normal_over.dds',
		callback = function()
			self:Show()
		end,
	}
	IPM_MENU = LMM:AddCategory(MENU_CATEGORY)

	local IPM_SCENE_GROUP_NAME = addon.name .. 'SceneGroup'
	self.SCENE_GROUP = ZO_SceneGroup:New(unpack(SCENES))
	SCENE_MANAGER:AddSceneGroup(IPM_SCENE_GROUP_NAME, self.SCENE_GROUP)

	LMM:AddSceneGroup(IPM_MENU, IPM_SCENE_GROUP_NAME, SUBMENU)
	LMM:AddMenuItem(IPM_SCENE_GROUP_NAME, MENU_CATEGORY)
end

-- TODO: refactor ?
function addon:Show()
	if not self.SCENE_GROUP:IsShowing() then
		LMM:ToggleCategory(IPM_MENU)
	end
end

function IPM_TogglePanel()
	LMM:ToggleCategory(IPM_MENU)
	-- TODO: highlight button in the menu itself
	-- :RefreshCategoryIndicators()
	-- :Update()
	-- ZO_MenuBar_ClearSelection(MAIN_MENU_KEYBOARD.categoryBar)
end

IPM_MAIN_MENU = addon