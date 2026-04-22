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

    local n_type = "item"

    if type(ingredient) == "string" then
        if data.raw.fluid[ingredient] then
            n_type = "fluid"
        end
    else
        if data.raw.fluid[ingredient.name or ingredient[1]] then
            n_type = "fluid"
        end
    end

    if type(ingredient) == "string" then
        normalized = {
            type = n_type,
            name = ingredient,
            amount = 1
        }
    else
        normalized = {
            type = ingredient.type or n_type,
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
---@param recipe_name string                Идентификатор рецепта
---@param tech_name string                  Идентификатор технологии
-- **********************************************************************************************
function CTDmod.lib.recipe.add_tech_unlock(recipe_name, tech_name)

    local recipe = data.raw.recipe[recipe_name]
    local tech = data.raw.technology[tech_name]

        -- проверка существования рецепта
    if not recipe then
        error("ОШИБКА: Рецепт '"..recipe_name.."' не найден!")
        return false
    end

        -- проверка существования технологии
    if not tech then
        error("ОШИБКА: Технология не найдена - '"..tech_name.."'")
        return false
    end

    if recipe.enabled ~= false then
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
---@param recipe_name string                Идентификатор рецепта
---@param old_tech string                   Идентификатор текущей технологии зависимости
---@param new_tech string                   Идентификатор новой технологии зависимости
-- **********************************************************************************************
function CTDmod.lib.recipe.change_tech_unlock(recipe_name, old_tech, new_tech)

        -- проверка существования рецепта
    if not data.raw.recipe[recipe_name] then
        error("ОШИБКА: Рецепт '"..recipe_name.."' не найден!")
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
---@param recipe_name string                Идентификатор рецепта
---@param tech_name string                  Идентификатор технологии
-- при конечном отсутствии технологических зависимостей рецепт доступен по умолчанию
-- **********************************************************************************************
function CTDmod.lib.recipe.remove_tech_unlock(recipe_name, tech_name)

    local recipe = data.raw.recipe[recipe_name]
    local tech = data.raw.technology[tech_name]

        -- проверка существования рецепта
    if not recipe then
        error("ОШИБКА: Рецепт '"..recipe_name.."' не найден!")
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
            if recipe.enabled ~= true then
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
---@param recipe_name string                Идентификатор рецепта
-- при конечном отсутствии технологических зависимостей рецепт доступен по умолчанию
-- **********************************************************************************************
function CTDmod.lib.recipe.remove_all_tech_unlocks(recipe_name)

    local recipe = data.raw.recipe[recipe_name]

            -- проверка существования рецепта
    if not recipe then
        error("ОШИБКА: Рецепт '"..recipe_name.."' не найден!")
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
        if recipe.enabled ~= true then
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

-- **********************************************************************************************
    -- ДОБАВЛЕНИЕ ИНГРЕДИЕНТА В РЕЦЕПТ
---@param recipe_name string                Идентификатор рецепта
---@param ingredient any (string or table)  примеры: 
-- "coal" или {"coal", 1} или {type = "item", name = "coal", amount = 1}
-- **********************************************************************************************
function CTDmod.lib.recipe.add_ingredient(recipe_name, ingredient)

    local recipe = data.raw.recipe[recipe_name]

        -- проверка существования рецепта
    if not recipe then
        error("ОШИБКА: Рецепт '"..recipe_name.."' не найден!")
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

    added = add_to_recipe_part(recipe) or added

    if added then
        log("ИНФО: Ингредиент '"..normalized.name.."' добавлен в рецепт '"..recipe_name.."'")
    end
    return added

end
-- ##############################################################################################

-- **********************************************************************************************
    -- ЗАМЕНА ИНГРЕДИЕНТА В РЕЦЕПТЕ
-- (если старый ингредиент = новый ингредиент, можно заменить кол-во)
---@param recipe_name string                Идентификатор рецепта
---@param old_ingredient string             Старый ингредиент
---@param new_ingredient any (string or table)  примеры: 
-- "coal" или {"coal", 1} или {type = "item", name = "coal", amount = 1}
-- **********************************************************************************************
function CTDmod.lib.recipe.replace_ingredient(recipe_name, old_ingredient, new_ingredient)

    local recipe = data.raw.recipe[recipe_name]

        -- проверка существования рецепта
    if not recipe then
        error("ОШИБКА: Рецепт '"..recipe_name.."' не найден!")
        return false
    end

    local replaced = false

    local normalized = normalized_ingredient(new_ingredient)

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
                    ing.name = normalized.name
                    ing.type = normalized.type
                    ing.amount = normalized.amount
                else
                    ing[1] = normalized.name
                    ing[2] = normalized.amount
                end
                return true

            end
        end

        return false

    end

    replaced = replace_in_recipe_part(recipe) or replaced

    if replaced then
        log("ИНФО: В рецепте '"..recipe_name.."' ингредиент '"..old_ingredient.."' заменен на '"..tostring(normalized.name).."'")
    else
        log("ИНФО: Ингредиент '"..old_ingredient.."' не найден в рецепте '"..recipe_name.."'")
    end
    return replaced

end
-- ##############################################################################################

-- **********************************************************************************************
    -- ЗАМЕНА ИНГРЕДИЕНТА ВО ВСЕХ РЕЦЕПТАХ 
---@param old_item string                   Идентификатор старого ингредиента
---@param new_item string                   Идентификатор нового ингредиента
-- **********************************************************************************************
function CTDmod.lib.recipe.replace_ingredient_everywhere(old_item, new_item)

        -- перебор всех рецептов
    for _, recipe in pairs(data.raw.recipe) do
        if recipe.ingredients then
            for _, ing in pairs(recipe.ingredients) do
                if ing.name and ing.name == old_item then
                    ing.name = new_item
                elseif ing[1] and ing[1] == old_item then
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
---@param recipe_name string                Идентификатор рецепта
---@param ingredient_name string            Идентификатор ингредиента
-- **********************************************************************************************
function CTDmod.lib.recipe.remove_ingredient(recipe_name, ingredient_name)

    local recipe = data.raw.recipe[recipe_name]

        -- проверка существования рецепта
    if not recipe then
        error("ОШИБКА: Рецепт '"..recipe_name.."' не найден!")
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

    removed = remove_from_recipe_part(recipe) or removed

    if removed then
        log("ИНФО: Ингредиент '"..ingredient_name.."' удален из рецепта '"..recipe_name.."'")
    else
        log("ИНФО: Ингредиент '"..ingredient_name.."' не найден в рецепте '"..recipe_name..'"')
    end
    return removed

end
-- ##############################################################################################

-- **********************************************************************************************
    -- ДОБАВЛЕНИЕ ПРЕДМЕТА В РЕЗАЛЬТАТЫ РЕЦЕПТА
---@param recipe_name string                Идентификатор рецепта
---@param new_item string                   Идентификатор результата
---@param amount number                     Кол-во результата
---@param probability number                Шанс результата (1.0 = 100%)
-- **********************************************************************************************
function CTDmod.lib.recipe.add_result(recipe_name, new_item, amount, probability)

    local recipe = data.raw.recipe[recipe_name]

        -- проверка существования рецепта
    if not recipe then
        error("ОШИБКА: Рецепт '"..recipe_name.."' не найден!")
        return false
    end

    if not (data.raw.item[new_item] or data.raw.tool[new_item] or data.raw.fluid[new_item]) then
        error("ОШИБКА: Предмет '"..new_item.."' не найден!")
        return false
    end

    local n_type = "item"

    if data.raw.fluid[new_item] then
        n_type = "fluid"
    end

    amount = amount or 1
    probability = probability or 1.0

    local function add_to_existing_results(results)
        if not results then
            return {{type = n_type, name = new_item, amount = amount, probability = probability}}
        end
        table.insert(results, {
            type = n_type,
            name = new_item,
            amount = amount,
            probability = probability
        })
        return results
    end


    recipe.results = {
        {
            type = n_type,
            name = recipe.result,
            amount = recipe.result_count or 1
        }
    }

    recipe.results = add_to_existing_results(recipe.results)
    if not recipe.main_product then
        recipe.main_product = recipe.results[1].name
    end

    log("ИНФО: Предмет '"..new_item.."' добавлен к рецепту '"..recipe_name.."'")
    return true
end
-- ##############################################################################################

-- **********************************************************************************************
    -- МАССОВОЕ ДОБАВЛЕНИЕ ПРЕДМЕТОВ К РЕЗУЛЬТАТАМ РЕЦЕПТА
---@param recipe_name string                Идентификатор рецепта
---@param items table                       Таблица предметов для добавления в формате:
-- {
--     {item = "item-name", amount = 1, probability = 1.0},
--     {item = "other-item", amount = 2, probability = 0.5}
-- }
-- **********************************************************************************************
function CTDmod.lib.recipe.add_results(recipe_name, items)

        -- проверка существования рецепта
    if not data.raw.recipe[recipe_name] then
        error("ОШИБКА: Рецепт '"..recipe_name.."' не найден!")
        return false
    end

    if type(items) ~= "table" then
        error("ОШИБКА: параметр 'items' должен быть таблицей!")
        return false
    end

    for _, item_data in ipairs(items) do
        local success = CTDmod.lib.recipe.add_result(
            recipe_name,
            item_data.item,
            item_data.amount,
            item_data.probability
        )
        if not success then
            return false
        end
    end

    log("ИНФО: Добавлено '"..#items.."' результатов к рецепту '"..recipe_name.."'")
    return true

end
-- ##############################################################################################

-- **********************************************************************************************
    -- ЗАМЕНА РЕЗУЛЬТАТА РЕЦЕПТА
---@param recipe_name string                Идентификатор рецепта
---@param old_item string                   Идентификатор старого результата
---@param new_item string                   Идентификатор нового результата
---@param new_amount number                 Новое кол-во
---@param new_probability number            Новая вероятность (1.0 = 100%)
-- **********************************************************************************************
function CTDmod.lib.recipe.replace_result(recipe_name, old_item, new_item, new_amount, new_probability)

    local recipe = data.raw.recipe[recipe_name]

        -- проверка существования рецепта
    if not recipe then
        error("ОШИБКА: Рецепт '"..recipe_name.."' не найден!")
        return false
    end

    if not (data.raw.item[old_item] or data.raw.tool[old_item] or data.raw.fluid[old_item]) then
        error("ОШИБКА: Старый результат '"..old_item.."' не найден в игре!")
        return false
    end

    if not (data.raw.item[new_item] or data.raw.tool[new_item] or data.raw.fluid[new_item]) then
        error("ОШИБКА: Новый результат '"..new_item.."' не найден в игре!")
        return false
    end

    local n_type = "item"

    if data.raw.fluid[new_item] then
        n_type = "fluid"
    end

    local replaced = false

    local function replace_in_results(results)
        if not results then return false end

        for _, result in ipairs(results) do
            local result_name = result.name or result[1]
            if result_name == old_item then
                result.name = new_item
                if result[1] then result[1] = new_item end
                if n_type ~= "item" then result.type = n_type end
                if new_amount then result.amount = new_amount end
                if new_probability then result.probability = new_probability end
                return true
            end
        end
        return false
    end

    replaced = replace_in_results(recipe.results) or replaced

    if replaced then
        log("ИНФО: Заменен результат '"..old_item.."' на '"..new_item.."' в рецепте '"..recipe_name.."'")
        return true
    else
        error("ОШИБКА: Резельтат '"..old_item.."' не найден в результатах рецепта '"..recipe_name.."'")
        return false
    end

end
-- ##############################################################################################

-- **********************************************************************************************
    -- ДУБЛИРОВАНИЕ РЕЦЕПТА С ВОЗМОЖНОСТЬЮ СКРЫТИЯ ОРИГИНАЛА
---@param orig_name string                  Идентификатор оригинального рецепта
---@param new_name string                   Идентификатор нового рецепта
---@param parameters table                  Таблица с новыми / изменеными параметрами рецепта
---@param hiding_from_player boolean        Скрыть из видимости крафта игрока (true / false)
-- **********************************************************************************************
function CTDmod.lib.recipe.duplicate(orig_name, new_name, parameters, hiding_from_player)

    local original = data.raw.recipe[orig_name]

        -- проверка существования оригинального рецепта
    if not original then
        error("ОШИБКА: Рецепт '"..orig_name.."' не найден!")
        return false
    end

    local recipe_copy = data.raw.recipe[new_name]

        -- проверка существования нового рецепта
    if recipe_copy then
        error("ОШИБКА: Рецепт '"..new_name.."' уже существует!")
        return false
    end

        -- 1. Изменение категории рецепта, если не существует - создать
    if parameters and parameters.category and not data.raw["recipe-category"][parameters.category] then
        data: extend ({
            {
                type = "recipe-category",
                name = parameters.category
            }
        })
    end

        -- 2. Копирование рецепта
    local copy = table.deepcopy(original)
    copy.name = new_name

        -- 3. Обновление параметров
    if parameters then
        for k, v in pairs(parameters) do
            copy[k] = v
        end
    end

        -- 4. Добавление дубликата рецепта
    data: extend({copy})

        -- 5. Поиск и копирование привязки к технологиям
    for _, tech in pairs(data.raw.technology) do
        if tech.effects then
            for _, effect in ipairs(tech.effects) do
                if effect.type == "unlock-recipe" and effect.recipe == orig_name then
                        -- добавляем копию рецепта в ту же технологию
                    table.insert(tech.effects, {
                        type = "unlock-recipe",
                        recipe = new_name
                    })
                    log("ИНФО: Рецепт '"..new_name.."' добавлен в разблокировку технологией '"..tech.name.."'")
                    break
                end
            end
        end
    end

        -- 6. Скрытие оригинального рецепта из крафта игрока (опционально)
    if hiding_from_player then
        original.hide_from_player_crafting = true
        log("ИНФО: Создан рецепт '"..new_name.."' на основе '"..orig_name.."'. Рецепт '"..orig_name.."' скрыт от игрока")
    else
        log("ИНФО: Создан рецепт '"..new_name.."' на основе '"..orig_name.."'")
    end

    return true

end
-- ##############################################################################################

-- **********************************************************************************************
    -- ПОЛНОЕ УДАЛЕНИЕ РЕЦЕПТА
---@param recipe_name string                Идентификатор удаляемого рецепта
---@return boolean
-- **********************************************************************************************
function CTDmod.lib.recipe.completely_delete(recipe_name)
    if not data.raw.recipe[recipe_name] then return false end

    -- 1. Собираем все предметы из результатов рецепта
    local result_items = {}
    local recipe = data.raw.recipe[recipe_name]

    local function collect_results(r)
        if r.result then
            result_items[r.result] = true
        end
        if r.results then
            for _, res in ipairs(r.results) do
                result_items[res.name or res[1]] = true
            end
        end
    end

    collect_results(recipe)

    -- 2. Обрабатываем предметы и связанные сущности
    for item_name, _ in pairs(result_items) do
        -- Находим предмет
        local item = data.raw.item[item_name] or data.raw.tool[item_name] or
                    data.raw.ammo[item_name] or data.raw.capsule[item_name] or
                    data.raw.module[item_name] or data.raw.gun[item_name] or
                    data.raw.armor[item_name]

        if item then
            -- Сначала обрабатываем связанные сущности (если есть place_result)
            if item.place_result then
                for _, entity_type in ipairs({
                    "inserter", "assembling-machine", "furnace", "mining-drill",
                    "lab", "transport-belt", "container", "wall", "reactor",
                    "boiler", "generator", "solar-panel", "accumulator",
                    "radar", "beacon", "roboport", "turret", "car", "locomotive"
                }) do
                    local entity = data.raw[entity_type] and data.raw[entity_type][item.place_result]
                    if entity then
                        -- Критически важная последовательность:
                        -- 1. Сначала убираем mining result если он ссылается на наш предмет
                        if entity.mineable and (entity.mineable.result == item_name or
                           (entity.mineable.results and #entity.mineable.results > 0)) then
                            entity.mineable = nil -- Полностью отключаем добычу
                        end

                        -- 2. Затем удаляем цепочку апгрейдов
                        entity.next_upgrade = nil

                        -- 3. Только потом скрываем сущность
                        entity.hidden = true
                        entity.hidden_in_factoriopedia = true
                    end
                end
            end

            -- Скрываем сам предмет
            item.hidden = true
            item.hidden_in_factoriopedia = true
        end
    end

    -- 3. Удаляем сам рецепт и все его упоминания
    data.raw.recipe[recipe_name] = nil

    -- 4. Чистим упоминания в технологиях
    for _, tech in pairs(data.raw.technology) do
        if tech.effects then
            for i = #tech.effects, 1, -1 do
                if tech.effects[i].type == "unlock-recipe" and tech.effects[i].recipe == recipe_name then
                    table.remove(tech.effects, i)
                end
            end
        end
    end

    -- 5. Чистим упоминания в ингредиентах других рецептов
    for _, other_recipe in pairs(data.raw.recipe) do
        local function clean_ingredients(ingredients)
            if not ingredients then return end
            for i = #ingredients, 1, -1 do
                local ing = ingredients[i]
                if (ing.name and ing.name == recipe_name) or (ing[1] and ing[1] == recipe_name) then
                    table.remove(ingredients, i)
                end
            end
        end

        clean_ingredients(other_recipe.ingredients)

    end

    log("Рецепт '"..recipe_name.."' и связанные объекты полностью удалены")
    return true
end
-- ##############################################################################################