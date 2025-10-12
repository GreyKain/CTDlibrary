-- ##############################################################################################
if not CTDmod.lib.character then
    CTDmod.lib.character = {}
end
-- ##############################################################################################
--- Функция для изменения категорий крафта персонажа
function CTDmod.lib.character.craft_categories(categories)
    -- Обрабатываем всех персонажей
    for _, char in pairs(data.raw["character"]) do

        if char.crafting_categories then
            -- Полная замена категорий
            char.crafting_categories = table.deepcopy(categories)
        end
    end
end
-- Пример использования:
-- CTDmod.lib.character.update_all_crafting({
--     "CTD-handmade",      -- Ваша новая категория
--     "crafting",          -- Стандартная категория ручного крафта
--     "advanced-crafting"  -- Дополнительные категории по необходимости
-- })
-- ##############################################################################################