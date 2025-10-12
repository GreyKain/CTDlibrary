-- ##############################################################################################
if not CTDmod.lib.recipe then CTDmod.lib.recipe = {} end
-- ##############################################################################################

-- **********************************************************************************************
    -- Нормализация записи ингредиента
---@param ingredient any                    принимает string or table,  примеры: 
-- "coal" или {"coal", 1} или {type = "item", name = "coal", amount = 1}
---@return table    -- возвращает в  виде таблицы {type = "item", name  = "item_name", amount = 1}
-- **********************************************************************************************
local function normalized_ingredient(ingredient)

    local normalized

    if type(ingredient) == "string" then
        normalized = {
            type = "item",
            name = ingredient,
            amount = 1
        }
    else
        normalized = {
            type = ingredient.type or "item",
            name = ingredient.name or ingredient[1],
            amount = ingredient.amount or ingredient[2] or 1
        }
    end

    if not normalized.name then
        error("ОШИБКА: Не указано имя ингредиента!")
    end

    return normalized

end
-- ##############################################################################################

-- **********************************************************************************************
    -- ДОБАВЛЕНИЕ ЗАВИСИМОСТИ ОТ ТЕХНОЛОГИИ ДЛЯ РЕЦЕПТА
---@param recipe_name string                идентификатор рецепта
---@param tech_name string                  идентификатор технологии
-- **********************************************************************************************
function CTDmod.lib.recipe.add_tech_unlock(recipe_name, tech_name)

    local recipe = data.raw.recipe[recipe_name]
    local tech = data.raw.technology[tech_name]

        -- проверка существования рецепта
    if not recipe then
        error("ОШИБКА: Рецепт не найден - '"..recipe_name.."'")
        return false
    end

        -- проверка существования технологии
    if not tech then
        error("ОШИБКА: Технология не найдена - '"..tech_name.."'")
        return false
    end

        -- обработка разных форматов рецептов
    if recipe.normal and recipe.normal.enabled ~= false then
        recipe.normal.enabled = false
        log("ИНФО: Нормальная версия рецепта '"..recipe_name.."' исключена из свободного крафта")
    end

    if recipe.expensive and recipe.expensive.enabled ~= false then
        recipe.expensive.enabled = false
        log("ИНФО: Дорогая версия рецепта '"..recipe_name.."' исключена из свободного крафта")
    end

    if not (recipe.normal or recipe.expensive) and recipe.enabled ~= false then
        recipe.enabled = false
        log("ИНФО: Рецепт '"..recipe_name.."' исключен из свободного крафта")
    end

        -- добавление разблокировки рецепта в технологию
    if not tech.effects then tech.effects = {} end

    table.insert(tech.effects, {type = "unlock-recipe", recipe = recipe_name})
    log("ИНФО: Рецепт '"..recipe_name.."' теперь зависит от технологии '"..tech_name.."'")
    return true

end
-- ##############################################################################################

-- **********************************************************************************************
    -- ИЗМЕНЕНИЕ ЗАВИСИМОСТИ ОТ ТЕХНОЛОГИИ ДЛЯ РЕЦЕПТА
---@param recipe_name string                идентификатор рецепта
---@param old_tech string                   идентификатор текущей технологии зависимости
---@param new_tech string                   идентификатор новой технологии зависимости
-- **********************************************************************************************
function CTDmod.lib.recipe.change_tech_unlock(recipe_name, old_tech, new_tech)

        -- проверка существования рецепта
    if not data.raw.recipe[recipe_name] then
        error("ОШИБКА: Рецепт не найден - '"..recipe_name.."'")
        return false
    end

        -- проверка существования технологий
    if not data.raw.technology[old_tech] then
        error("ОШИБКА: Технология текущей зависимости не найдена - '"..old_tech.."'")
        return false
    end

    if not data.raw.technology[new_tech] then
        error("ОШИБКА: Технология новой зависимости не найдена - '"..new_tech.."'")
        return false
    end

        -- обновление технологии если рецепт в её эффектах
    for _, tech in pairs(data.raw.technology) do
        if tech.effects then
            for _, effect in ipairs(tech.effects) do
                if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
                    if tech.name == old_tech then
                            -- создаем эффект в новой технологии
                        table.insert(data.raw.technology[new_tech].effects,
                            {type = "unlock-recipe", recipe = recipe_name}
                        )
                            -- удаляем эффект из старой технологии
                        for i, eff in ipairs(tech.effects) do
                            if eff.type == "unlock-recipe" and eff.recipe == recipe_name then
                                table.remove(tech.effects, i)
                                log("ИНФО: Зависимость рецепта '"..recipe_name.."' изменена с '"..old_tech.."' на '"..new_tech.."'")
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end
-- ##############################################################################################

-- **********************************************************************************************
    -- УДАЛЕНИЕ ЗАВИСИМОСТИ ОТ ТЕХНОЛОГИИ ДЛЯ РЕЦЕПТА
---@param recipe_name string                идентификатор рецепта
---@param tech_name string                  идентификатор технологии
-- при конечном отсутствии технологических зависимостей рецепт доступен по умолчанию
-- **********************************************************************************************
function CTDmod.lib.recipe.remove_tech_unlock(recipe_name, tech_name)

    local recipe = data.raw.recipe[recipe_name]
    local tech = data.raw.technology[tech_name]

        -- проверка существования рецепта
    if not recipe then
        error("ОШИБКА: Рецепт не найден - '"..recipe_name.."'")
        return false
    end

        -- проверка существования технологии
    if not tech then
        error("ОШИБКА: Технология не найдена - '"..tech_name.."'")
        return false
    end

    local remove_unlock = true
    local remove_from_tech = false

        -- удаление разблокировки рецепта из технологии
    if tech and tech.effects then
        for i = #tech.effects, 1, -1 do
            local effect = tech.effects[i]
            if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
                table.remove(tech.effects, i)
                remove_from_tech = true
            end
        end

            -- удаление пустой таблицы если эффектов не осталось
        if tech.effects and #tech.effects == 0 then
            tech.effects = nil
        end
    end

        -- ищем разблокировку рецепта во всех технологиях
    for t, current_tech in pairs(data.raw.technology) do
        if t ~= tech_name and current_tech.effects then
            for _, effect in ipairs(current_tech.effects) do
                if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
                    remove_unlock = false
                    break
                end
            end
            if remove_unlock == false then
                break
            end
        end
    end

    if remove_from_tech then
        log("ИНФО: Зависимость рецепта '"..recipe_name.."' от технологии '"..tech_name.."' удалена")
            -- если технологий разблокировки не осталось включаем рецепт по умолчанию
        if remove_unlock == true then
            if recipe.normal and recipe.normal.enabled ~= true then
                recipe.normal.enabled = true
            end
            if recipe.expensive and recipe.expensive.enabled ~= true then
                recipe.expensive.enabled = true
            end
            if not (recipe.normal or recipe.expensive) and recipe.enabled ~= true then
                recipe.enabled = true
            end
            log("ИНФО: Рецепт '"..recipe_name.."' больше не требует технологий для разблокировки")
        end
        return true
    else
        log("ИНФО: Зависимость рецепта '"..recipe_name.."' от технологии '"..tech_name.."' не найдена")
        return false
    end

end
-- ##############################################################################################

-- **********************************************************************************************
    -- ПОЛНОЕ УДАЛЕНИЕ ТЕХНОЛОГИЧЕСКИХ ЗАВИСИМОСТЕЙ РЕЦЕПТА
---@param recipe_name string                идентификатор рецепта
-- при конечном отсутствии технологических зависимостей рецепт доступен по умолчанию
-- **********************************************************************************************
function CTDmod.lib.recipe.remove_all_tech_unlocks(recipe_name)

    local recipe = data.raw.recipe[recipe_name]

            -- проверка существования рецепта
    if not recipe then
        error("ОШИБКА: Рецепт не найден - '"..recipe_name.."'")
        return false
    end

    local removed_count = 0

        -- удаление эффектов разблокировки рецепта из технологий
    for _, tech in pairs(data.raw.technology) do
        if tech.effects then
            for i = #tech.effects, 1, -1 do
                local effect = tech.effects[i]
                if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
                    table.remove(tech.effects, i)
                    removed_count = removed_count + 1
                end
            end

            if tech.effects and #tech.effects == 0 then
                tech.effects = nil
            end
        end
    end

    if removed_count > 0 then
        if recipe.normal and recipe.normal.enabled ~= true then
            recipe.normal.enabled = true
        end
        if recipe.expensive and recipe.expensive.enabled ~= true then
            recipe.expensive.enabled = true
        end
        if not (recipe.normal or recipe.expensive) and recipe.enabled ~= true then
            recipe.enabled = true
        end
        log("ИНФО: Удалены все технологические зависимости рецепта '"..recipe_name.."' из "..removed_count.." технологии(ий)")
        return true
    else
        log("ИНФО: Технологических зависимостей рецепта '"..recipe_name.."' не найдено")
        return false
    end

end
-- ##############################################################################################

-- ##############################################################################################

-- **********************************************************************************************
    -- ДОБАВЛЕНИЕ ИНГРЕДИЕНТА В РЕЦЕПТ
---@param recipe_name string                идентификатор рецепта
---@param ingredient any (string or table)  примеры: 
-- "coal" или {"coal", 1} или {type = "item", name = "coal", amount = 1}
-- **********************************************************************************************
function CTDmod.lib.recipe.add_ingredient(recipe_name, ingredient)

    local recipe = data.raw.recipe[recipe_name]

        -- проверка существования рецепта
    if not recipe then
        error("ОШИБКА: Рецепт не найден - '"..recipe_name.."'")
        return false
    end

    local normalized = normalized_ingredient(ingredient)

    local function add_to_recipe_part(recipe_part)
        if not recipe_part.ingredients then
            recipe_part.ingredients = {}
        end

        -- проверка существования ингредиента в текущем рецепте
        for _, exist in ipairs(recipe_part.ingredients) do
            if  (exist.name and exist.name == normalized.name) or
                (exist[1] and exist[1] == normalized.name) then
                log("Ингредиент '"..normalized.name.."' уже есть в рецепте")
                return false
            end
        end

        -- добавление ингредиента в рецепт   
        table.insert(recipe_part.ingredients, {
            type = normalized.type,
            name = normalized.name,
            amount = normalized.amount
        })
        return true
    end

    local added = false

    -- добавление в разные варианты рецептов
    if recipe.normal then
        added = add_to_recipe_part(recipe.normal) or added
    end
    if recipe.expensive then
        added = add_to_recipe_part(recipe.expensive) or added
    end
    if not (recipe.normal or recipe.expensive) then
        added = add_to_recipe_part(recipe) or added
    end

    if added then
        log("ИНФО: Ингредиент '"..normalized.name.."' добавлен в рецепт '"..recipe_name.."'")
    end
    return added

end
-- ##############################################################################################

-- **********************************************************************************************
    -- ЗАМЕНА ИНГРЕДИЕНТА В РЕЦЕПТЕ
---@param recipe_name string                идентификатор рецепта
---@param old_ingredient string             старый ингредиент
---@param new_ingredient any (string or table)  примеры: 
-- "coal" или {"coal", 1} или {type = "item", name = "coal", amount = 1}
-- **********************************************************************************************
function CTDmod.lib.recipe.replace_ingredient(recipe_name, old_ingredient, new_ingredient)

    local recipe = data.raw.recipe[recipe_name]

        -- проверка существования рецепта
    if not recipe then
        error("ОШИБКА: Рецепт не найден - '"..recipe_name.."'")
        return false
    end

    local replaced = false

        -- Функция замены в конкретной части рецепта
    local function replace_in_recipe_part(recipe_part)

        if not recipe_part.ingredients then return false end

        for _, ing in ipairs(recipe_part.ingredients) do
                -- обработка разных форматов ингредиентов
            if (ing.name and ing.name == old_ingredient) or
            (ing[1] and ing[1] == old_ingredient) then
                    -- сохранение кол-ва из старого ингредиента
                local amount = ing.amount or ing[2] or 1

                    -- замена ингредиента
                if ing.name then
                    ing.name = new_ingredient.name or new_ingredient
                    ing.type = new_ingredient.type or "item"
                    ing.amount = new_ingredient.amount or amount
                else
                    ing[1] = new_ingredient.name or new_ingredient
                    ing[2] = new_ingredient.amount or amount
                end
                return true

            end
        end

        return false

    end

        -- замена в разных вариантах рецепта
    if recipe.normal then
        replaced = replace_in_recipe_part(recipe.normal) or replaced
    end
    if recipe.expensive then
        replaced = replace_in_recipe_part(recipe.expensive) or replaced
    end
    if not (recipe.normal or recipe.expensive) then
        replaced = replace_in_recipe_part(recipe) or replaced
    end

    if replaced then
        log("ИНФО: В рецепте '"..recipe_name.."' ингредиент '"..old_ingredient.."' заменен на '"..(new_ingredient.name or new_ingredient).."'")
    else
        log("ИНФО: Ингредиент '"..old_ingredient.."' не найден в рецепте '"..recipe_name.."'")
    end
    return replaced

end
-- ##############################################################################################

-- **********************************************************************************************
    -- ЗАМЕНА ИНГРЕДИЕНТА ВО ВСЕХ РЕЦЕПТАХ 
---@param old_item string                   идентификатор старого ингредиента
---@param new_item string                   идентификатор нового ингредиента
-- **********************************************************************************************
function CTDmod.lib.recipe.replace_ingredient_everywhere(old_item, new_item)

        -- перебор всех рецептов
    for _, recipe in pairs(data.raw.recipe) do
            -- обычные рецепты
        if recipe.ingredients then
            for _, ing in pairs(recipe.ingredients) do
                if ing.name and ing.name == old_item then
                    ing.name = new_item
                elseif ing[1] and ing[1] == old_item then
                    ing[1] = new_item
                end
            end
        end
            -- нормальные рецепты
        if recipe.normal and recipe.normal.ingredients then
            for _, ing in pairs(recipe.normal.ingredients) do
                if ing.name and ing.name == old_item then
                    ing.name = new_item
                elseif  ing[1] and ing[1] == old_item then
                    ing[1] = new_item
                end
            end
        end
            -- дорогие рецепты
        if recipe.expensive and recipe.expensive.ingredients then
            for _, ing in pairs(recipe.expensive.ingredients) do
                if ing.name and ing.name == old_item then
                    ing.name = new_item
                elseif  ing[1] and ing[1] == old_item then
                    ing[1] = new_item
                end
            end
        end
    end

    --     -- проверка технологий на требование предмета для исследования
    -- for _, tech in pairs(data.raw.technology) do
    --     if tech.unit and tech.unit.ingredients then
    --         for _, ing in pairs(tech.unit.ingredients) do
    --             if ing.name and ing.name == old_item then
    --                 ing.name = new_item
    --             elseif ing[1] and ing[1] == old_item then
    --                 ing[1] = new_item
    --             end
    --         end
    --     end
    -- end

    log("ИНФО: Ингредиент '"..old_item.."' заменен на '"..new_item.."' во всех рецептах")

end
-- ##############################################################################################

-- **********************************************************************************************
    -- УДАЛЕНИЕ ИНГРЕДИЕНТА ИЗ РЕЦЕПТА
---@param recipe_name string                идентификатор рецепта
---@param ingredient_name string            идентификатор ингредиента
-- **********************************************************************************************
function CTDmod.lib.recipe.remove_ingredient(recipe_name, ingredient_name)

    local recipe = data.raw.recipe[recipe_name]

        -- проверка существования рецепта
    if not recipe then
        error("ОШИБКА: Рецепт не найден - '"..recipe_name.."'")
        return false
    end

    local removed = false

    local function remove_from_recipe_part(recipe_part)
        if not recipe_part.ingredients then return false end

        for i = #recipe_part.ingredients, 1, -1 do
            local ing = recipe_part.ingredients[i]
            if (ing.name and ing.name == ingredient_name) or
            (ing[1] and ing[1] == ingredient_name) then
                table.remove(recipe_part.ingredients, i)
                return true
            end
        end
        return false
    end

        -- удаление из разных вариантов рецептов
    if recipe.normal then
        removed = remove_from_recipe_part(recipe.normal) or removed
    end
    if recipe.expensive then
        removed = remove_from_recipe_part(recipe.expensive) or removed
    end
    if not (recipe.normal or recipe.expensive) then
        removed = remove_from_recipe_part(recipe) or removed
    end

    if removed then
        log("ИНФО: Ингредиент '"..ingredient_name.."' удален из рецепта '"..recipe_name.."'")
    else
        log("ИНФО: Ингредиент '"..ingredient_name.."' не найден в рецепте '"..recipe_name..'"')
    end
    return removed

end
-- ##############################################################################################

-- ##############################################################################################

-- **********************************************************************************************
    -- УСТАНАВЛИВАЕТ ВРЕМЯ, НЕОБХОДИМОЕ ДЛЯ СОЗДАНИЯ РЕЦЕПТА
---@param recipe_name string                идентификатор рецепта
---@param new_energy number                 время в секундах
-- **********************************************************************************************
function CTDmod.lib.recipe.set_energy_required(recipe_name, new_energy)

    local recipe = data.raw.recipe[recipe_name]

        -- проверка существования рецепта
    if not recipe then
        error("ОШИБКА: Рецепт не найден - '"..recipe_name.."'")
        return false
    end

        -- проверка корректности нового значения времени
    if type(new_energy) ~= "number" or new_energy <=0 then
        error("ОШИБКА: Некорректное значение energy_required: "..tostring(new_energy))
        return false
    end

    local function modify_energy(recipe_table)
        recipe_table.energy_required = new_energy
    end

        -- обыный рецепт
    if not (recipe.normal or recipe.expensive) then
        modify_energy(recipe)
    else
            -- рецепты с нормальной / дорогой версиями
        if recipe.normal then
            modify_energy(recipe.normal)
        end
        if recipe.expensive then
            modify_energy(recipe.expensive)
        end
    end

    log("ИНФО: Время крафта для '"..recipe_name.."' установлено в "..tostring(new_energy).." сек.")
    return true

end
-- ##############################################################################################