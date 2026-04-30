-- ##############################################################################################
    -- Библиотека для работы с технологиями Factorio 2.0+
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
local util = require("util")
local tech_raw = data.raw.technology
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
    -- Инициализация модуля
if not CTDmod.lib.tech then CTDmod.lib.tech = {} end
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
    -- Вспомогательная функция: нормализация ингредиентов технологий к новому формату Factorio 2.0
-- ----------------------------------------------------------------------------------------------
local function normalize_ingredients(ingredients)
    if not ingredients then return {} end

    local normalized = {}
    for _, ingredient in ipairs(ingredients) do
        if type(ingredient) == "string" then
            -- Старый формат: "pack-name" -> amount = 1
            table.insert(normalized, {type = "item", name = ingredient, amount = 1})
        elseif type(ingredient) == "table" then
            if ingredient[1] and not ingredient.name then
                -- Старый формат: {"pack-name", amount}
                table.insert(normalized, {type = "item", name = ingredient[1], amount = ingredient[2] or 1})
            elseif ingredient.name then
                -- Новый формат: {type="item", name="pack", amount=1}
                local new_ing = {
                    type = ingredient.type or "item",
                    name = ingredient.name,
                    amount = ingredient.amount or 1
                }
                table.insert(normalized, new_ing)
            elseif ingredient.type == "item" and not ingredient.name then
                -- Некорректный формат, пытаемся восстановить
                log("WARNING: Incorrect ingredient format: " .. serpent.line(ingredient))
            end
        end
    end
    return normalized
end
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
    -- Вспомогательная функция: проверка существования предмета
-- ----------------------------------------------------------------------------------------------
local function item_exists(item_name)
    return data.raw.tool[item_name] ~= nil or
           data.raw.item[item_name] ~= nil or
           data.raw.capsule[item_name] ~= nil
end
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
    -- Функция добавления зависимости технологии:
-- ----------------------------------------------------------------------------------------------
function CTDmod.lib.tech.add_dependency(tech_name, dependency)
    -- Проверяем существование технологии
    if not tech_raw[tech_name] then
        error("Технология '"..tech_name.."' не найдена!")
    end

    -- Проверяем существование зависимости
    if not tech_raw[dependency] then
        error("Технология-зависимость '"..dependency.."' не найдена!")
    end

    -- Инициализируем prerequisites если нет
    if not tech_raw[tech_name].prerequisites then
        tech_raw[tech_name].prerequisites = {}
    end

    -- Проверяем, нет ли уже такой зависимости
    for _, prereq in ipairs(tech_raw[tech_name].prerequisites) do
        if prereq == dependency then
            log("Технология '"..tech_name.."' уже зависит от '"..dependency.."'")
            return true
        end
    end

    -- Добавляем зависимость
    table.insert(tech_raw[tech_name].prerequisites, dependency)
    log("Добавлена зависимость: '"..tech_name.."' теперь требует '"..dependency.."'")
    return true
end
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
    -- Функция замены зависимости технологии:
-- ----------------------------------------------------------------------------------------------
function CTDmod.lib.tech.replace_dependency(tech_name, old_dependency, new_dependency)
    -- Проверяем существование технологий
    if not tech_raw[tech_name] then
        error("Технология '"..tech_name.."' не найдена!")
    end
    if not tech_raw[new_dependency] then
        error("Новая технология-зависимость '"..new_dependency.."' не найдена!")
    end

    if not tech_raw[tech_name].prerequisites then
        error("У технологии '"..tech_name.."' нет зависимостей!")
    end

    -- Ищем и заменяем зависимость
    local found = false
    for i, prereq in ipairs(tech_raw[tech_name].prerequisites) do
        if prereq == old_dependency then
            tech_raw[tech_name].prerequisites[i] = new_dependency
            found = true
            break -- Заменяем только первое вхождение
        end
    end

    if not found then
        error("Технология '"..tech_name.."' не зависит от '"..old_dependency.."'")
    end

    log("Зависимость заменена: '"..tech_name.."' теперь требует '"..new_dependency.."' вместо '"..old_dependency.."'")
    return true
end
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
    -- Заменяет или удаляет зависимости технологий
-- ----------------------------------------------------------------------------------------------
-- @param old_tech string - Исходная технология (например "electronics")
-- @param new_tech string - Новая технология (например "CTD-electronics")
function CTDmod.lib.tech.replace_or_remove_dependencies(old_tech, new_tech)
    -- Проверяем существование новой технологии
    local new_tech_exists = tech_raw[new_tech] ~= nil
    local replacements = 0
    local removals = 0

    -- Проходим по всем технологиям
    for _, tech in pairs(tech_raw) do
        -- Обрабатываем прямые зависимости (prerequisites)
        if tech.prerequisites then
            -- Проверяем, есть ли уже новая технология в зависимостях
            local has_new_tech = false
            local indices_to_remove = {}

            for i, prereq in ipairs(tech.prerequisites) do
                if prereq == new_tech then
                    has_new_tech = true
                end
                if prereq == old_tech then
                    table.insert(indices_to_remove, i)
                end
            end

            -- Обрабатываем найденные старые зависимости с конца
            for i = #indices_to_remove, 1, -1 do
                local index = indices_to_remove[i]
                if new_tech_exists and not has_new_tech then
                    tech.prerequisites[index] = new_tech
                    replacements = replacements + 1
                    has_new_tech = true -- Чтобы не заменять другие вхождения
                else
                    table.remove(tech.prerequisites, index)
                    removals = removals + 1
                end
            end

            -- Очищаем пустую таблицу
            if #tech.prerequisites == 0 then
                tech.prerequisites = nil
            end
        end
    end

    -- Формируем отчет
    local report_parts = {}
    if replacements > 0 then
        table.insert(report_parts, "Заменено "..replacements.." зависимостей")
    end
    if removals > 0 then
        table.insert(report_parts, "удалено "..removals.." зависимостей")
    end

    local report = table.concat(report_parts, ", ")
    if report ~= "" then
        log(report.." от '"..old_tech.."'")
    else
        log("Не найдено зависимостей от '"..old_tech.."'")
    end
    return true
end
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
    -- Функция удаления зависимости технологии:
-- ----------------------------------------------------------------------------------------------
function CTDmod.lib.tech.remove_dependency(tech_name, dependency)
    -- Проверяем существование технологии
    if not tech_raw[tech_name] then
        error("Технология '"..tech_name.."' не найдена!")
    end

    if not tech_raw[tech_name].prerequisites then
        error("У технологии '"..tech_name.."' нет зависимостей!")
    end

    -- Удаляем зависимость
    local found = false
    for i = #tech_raw[tech_name].prerequisites, 1, -1 do
        if tech_raw[tech_name].prerequisites[i] == dependency then
            table.remove(tech_raw[tech_name].prerequisites, i)
            found = true
        end
    end

    if not found then
        error("Технология '"..tech_name.."' не зависит от '"..dependency.."'")
    end

    -- Удаляем пустые таблицы зависимостей
    if #tech_raw[tech_name].prerequisites == 0 then
        tech_raw[tech_name].prerequisites = nil
    end

    log("Зависимость удалена: '"..tech_name.."' больше не требует '"..dependency.."'")
    return true
end
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
    -- Массовое добавление зависимостей:
-- ----------------------------------------------------------------------------------------------
function CTDmod.lib.tech.mass_add_dependencies(tech_name, dependencies)
    if not tech_raw[tech_name] then
        error("Технология '"..tech_name.."' не найдена!")
    end

    local success_count = 0
    for _, dep in ipairs(dependencies) do
        if CTDmod.lib.tech.add_dependency(tech_name, dep) then
            success_count = success_count + 1
        end
    end
    log("Добавлено "..success_count.." зависимостей к технологии '"..tech_name.."'")
    return success_count > 0
end
-- ##############################################################################################

-- ##############################################################################################
    -- Функция для полного удаления технологии:
-- ----------------------------------------------------------------------------------------------
function CTDmod.lib.tech.completely_delete(tech_name)
    -- Проверяем существование технологии
    if not tech_raw[tech_name] then
        error("Технология '"..tech_name.."' не найдена!")
    end

    local affected_recipes = {}

    -- 1. Удаляем технологию из зависимостей других технологий
    for _, tech in pairs(tech_raw) do
        if tech.prerequisites then
            for i = #tech.prerequisites, 1, -1 do
                if tech.prerequisites[i] == tech_name then
                    table.remove(tech.prerequisites, i)
                end
            end

            -- Удаляем пустые таблицы prerequisites
            if tech.prerequisites and #tech.prerequisites == 0 then
                tech.prerequisites = nil
            end
        end
    end

    -- 2. Обрабатываем связанные рецепты
    if tech_raw[tech_name].effects then
        for _, effect in ipairs(tech_raw[tech_name].effects) do
            if effect.type == "unlock-recipe" then
                local recipe = data.raw.recipe[effect.recipe]
                if recipe then
                    -- Удаляем привязку к технологии в рецепте
                    if recipe.technology == tech_name then
                        recipe.technology = nil
                        recipe.enabled = false -- Делаем рецепт недоступным
                        table.insert(affected_recipes, effect.recipe)
                    end
                end
            end
        end
    end

    -- 3. Полностью удаляем технологию
    tech_raw[tech_name] = nil

    if #affected_recipes > 0 then
        log("Технология '"..tech_name.."' полностью удалена. Затронуто рецептов: "..table.concat(affected_recipes, ", "))
    else
        log("Технология '"..tech_name.."' полностью удалена из игры")
    end
    return true
end
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
    -- Функция для отключения (но не удаления) технологии:
-- ----------------------------------------------------------------------------------------------
function CTDmod.lib.tech.disable(tech_name)
    if not tech_raw[tech_name] then
        error("Технология '"..tech_name.."' не найдена!")
    end

    tech_raw[tech_name].enabled = false
    tech_raw[tech_name].hidden = true

    log("Технология '"..tech_name.."' отключена и скрыта")
    return true
end
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
    -- Функция для переноса всех разблокируемых рецептов:
-- ----------------------------------------------------------------------------------------------
function CTDmod.lib.tech.transfer_effects(source_tech, target_tech)
    if not tech_raw[source_tech] then
        error("Исходная технология '"..source_tech.."' не найдена!")
    end
    if not tech_raw[target_tech] then
        error("Целевая технология '"..target_tech.."' не найдена!")
    end

    local source = tech_raw[source_tech]
    local target = tech_raw[target_tech]
    local transferred_count = 0

    if source.effects then
        -- Инициализируем effects если нет
        if not target.effects then
            target.effects = {}
        end

        -- Переносим все эффекты
        local new_effects = {}
        for _, effect in ipairs(source.effects) do
            if effect.type == "unlock-recipe" then
                table.insert(target.effects, effect)
                transferred_count = transferred_count + 1
            else
                -- Сохраняем другие эффекты
                table.insert(new_effects, effect)
            end
        end

        -- Обновляем исходные эффекты, оставляя не-рецепты
        if #new_effects > 0 then
            source.effects = new_effects
        else
            source.effects = nil
        end
    end

    log("Перенесено "..transferred_count.." эффектов из '"..source_tech.."' в '"..target_tech.."'")
    return true
end
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
    -- Функция для переименования технологии с возможностью подставления параметров в описание:
-- ----------------------------------------------------------------------------------------------
function CTDmod.lib.tech.rename(tech_name, tech_new_name, params)
    -- Проверяем существование технологии
    if not tech_raw[tech_name] then
        error("Технология '"..tech_name.."' не найдена!")
    end

    -- Если новое имя не указано - только обновляем локализацию
    if not tech_new_name or tech_new_name == tech_name then
        tech_raw[tech_name].localised_name = {"technology-name."..tech_name}
        if params ~= nil then
            tech_raw[tech_name].localised_description = {"technology-description."..tech_name, params}
        else
            tech_raw[tech_name].localised_description = {"technology-description."..tech_name}
        end
        return true
    end

    -- 1. Создаем полную копию технологии
    local tech_copy = util.table.deepcopy(tech_raw[tech_name])
    tech_copy.name = tech_new_name
    tech_copy.localised_name = {"technology-name."..tech_new_name}
    if params ~= nil then
        tech_copy.localised_description = {"technology-description."..tech_new_name, params}
    else
        tech_copy.localised_description = {"technology-description."..tech_new_name}
    end

    -- 2. Обновляем все зависимости в других технологиях
    for _, other_tech in pairs(tech_raw) do
        if other_tech.prerequisites then
            for i, prereq in ipairs(other_tech.prerequisites) do
                if prereq == tech_name then
                    other_tech.prerequisites[i] = tech_new_name
                end
            end
        end
    end

    -- 3. Обновляем рецепты (разблокировку технологий)
    for _, recipe in pairs(data.raw.recipe) do
        -- Обычные рецепты
        if recipe.enabled == false then
            if recipe.technology == tech_name then
                recipe.technology = tech_new_name
            end
        end
    end

    -- 4. Обновляем эффекты технологий
    if tech_copy.effects then
        for _, effect in ipairs(tech_copy.effects) do
            if effect.type == "unlock-recipe" and effect.recipe then
                local recipe = data.raw.recipe[effect.recipe]
                if recipe then
                    recipe.technology = tech_new_name
                end
            end
        end
    end

    -- 5. Добавляем новую технологию перед удалением старой
    tech_raw[tech_new_name] = tech_copy
    tech_raw[tech_name] = nil

    log("Технология '"..tech_name.."' переименована в '"..tech_new_name.."' со всеми связями")
    return true
end
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
    -- Добавляем научный пакет к технологии (Factorio 2.0+ формат)
-- ----------------------------------------------------------------------------------------------
-- @param tech_name Название технологии
-- @param science_pack Название научного пакета
-- @param amount Количество (по умолчанию 1)
function CTDmod.lib.tech.add_science_pack(tech_name, science_pack, amount)
    amount = amount or 1

    if not tech_raw[tech_name] then
        error("Технология '"..tech_name.."' не найдена!")
        return false
    end

    if not item_exists(science_pack) then
        error("Предмет '"..science_pack.."' не найден в data.raw!")
        return false
    end

    tech_raw[tech_name].unit = tech_raw[tech_name].unit or {}

    -- Нормализуем существующие ингредиенты к новому формату
    if tech_raw[tech_name].unit.ingredients then
        tech_raw[tech_name].unit.ingredients = normalize_ingredients(tech_raw[tech_name].unit.ingredients)
    else
        tech_raw[tech_name].unit.ingredients = {}
    end

    -- Проверяем, есть ли уже такой пакет
    for _, ingredient in pairs(tech_raw[tech_name].unit.ingredients) do
        if ingredient.name == science_pack then
            ingredient.amount = (ingredient.amount or 1) + amount
            log("Увеличено количество пакета '"..science_pack.."' до "..ingredient.amount.." в технологии '"..tech_name.."'")
            return true
        end
    end

    -- Добавляем новый пакет в формате Factorio 2.0
    table.insert(tech_raw[tech_name].unit.ingredients, {
        type = "item",
        name = science_pack,
        amount = amount
    })
    log("Добавлен пакет '"..science_pack.."' x"..amount.." в технологию '"..tech_name.."'")
    return true
end
-- ##############################################################################################

-- ##############################################################################################
    -- Удаляем научный пакет из технологии
-- ----------------------------------------------------------------------------------------------
-- @param tech_name Название технологии
-- @param science_pack Название научного пакета
-- @param remove_all Полностью удалить (true) или уменьшить количество (false)
-- @param amount Количество для удаления (по умолчанию 1)
function CTDmod.lib.tech.remove_science_pack(tech_name, science_pack, remove_all, amount)
    amount = amount or 1

    if not tech_raw[tech_name] then
        error("Технология '"..tech_name.."' не найдена!")
        return false
    end

    if not tech_raw[tech_name].unit or not tech_raw[tech_name].unit.ingredients then
        log("У технологии '"..tech_name.."' нет научных пакетов")
        return false
    end

    -- Нормализуем ингредиенты
    tech_raw[tech_name].unit.ingredients = normalize_ingredients(tech_raw[tech_name].unit.ingredients)

    for i, ingredient in ipairs(tech_raw[tech_name].unit.ingredients) do
        if ingredient.name == science_pack then
            if remove_all then
                table.remove(tech_raw[tech_name].unit.ingredients, i)
                log("Пакет '"..science_pack.."' полностью удален из технологии '"..tech_name.."'")
            else
                local new_amount = ingredient.amount - amount
                if new_amount <= 0 then
                    table.remove(tech_raw[tech_name].unit.ingredients, i)
                    log("Пакет '"..science_pack.."' удален из технологии '"..tech_name.."' (количество стало <= 0)")
                else
                    ingredient.amount = new_amount
                    log("Количество пакета '"..science_pack.."' уменьшено до "..new_amount.." в технологии '"..tech_name.."'")
                end
            end

            -- Удаляем пустую таблицу
            if #tech_raw[tech_name].unit.ingredients == 0 then
                tech_raw[tech_name].unit.ingredients = nil
            end
            return true
        end
    end

    log("Пакет '"..science_pack.."' не найден в технологии '"..tech_name.."'")
    return false
end
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
    -- Заменяем один научный пакет на другой
-- ----------------------------------------------------------------------------------------------
-- @param tech_name Название технологии
-- @param old_pack Название заменяемого пакета
-- @param new_pack Название нового пакета
-- @param new_amount Количество нового пакета (nil = сохранить старое количество)
function CTDmod.lib.tech.replace_science_pack(tech_name, old_pack, new_pack, new_amount)
    if not tech_raw[tech_name] then
        error("Технология '"..tech_name.."' не найдена!")
        return false
    end

    if not item_exists(new_pack) then
        error("Новый пакет '"..new_pack.."' не найден!")
        return false
    end

    if not tech_raw[tech_name].unit or not tech_raw[tech_name].unit.ingredients then
        log("У технологии '"..tech_name.."' нет научных пакетов")
        return false
    end

    -- Нормализуем ингредиенты
    tech_raw[tech_name].unit.ingredients = normalize_ingredients(tech_raw[tech_name].unit.ingredients)

    local found = false

    for _, ingredient in ipairs(tech_raw[tech_name].unit.ingredients) do
        if ingredient.name == old_pack then
            local saved_amount = ingredient.amount
            ingredient.name = new_pack
            ingredient.amount = new_amount or saved_amount
            found = true
            log("Пакет '"..old_pack.."' заменен на '"..new_pack.."' x"..ingredient.amount.." в технологии '"..tech_name.."'")
            break -- Заменяем только первое вхождение
        end
    end

    if not found then
        log("Пакет '"..old_pack.."' не найден в технологии '"..tech_name.."'")
    end

    return found
end
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
    -- Полностью заменяем все научные пакеты технологии
-- ----------------------------------------------------------------------------------------------
-- @param tech_name Название технологии
-- @param new_ingredients Таблица новых ингредиентов в формате {{"pack1", amount}, {"pack2", amount}}
function CTDmod.lib.tech.set_science_packs(tech_name, new_ingredients)
    if not tech_raw[tech_name] then
        error("Технология '"..tech_name.."' не найдена!")
        return false
    end

    tech_raw[tech_name].unit = tech_raw[tech_name].unit or {}
    tech_raw[tech_name].unit.ingredients = {}

    for _, pack in ipairs(new_ingredients) do
        if not item_exists(pack[1]) then
            log("WARNING: Пакет '"..pack[1].."' не найден при установке требований для '"..tech_name.."'")
        end
        table.insert(tech_raw[tech_name].unit.ingredients, {
            type = "item",
            name = pack[1],
            amount = pack[2] or 1
        })
    end

    log("Установлены новые требования для технологии '"..tech_name.."': "..#new_ingredients.." пакетов")
    return true
end
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
    -- Получаем список научных пакетов технологии
-- ----------------------------------------------------------------------------------------------
-- @param tech_name Название технологии
-- @return Таблица пакетов или nil
function CTDmod.lib.tech.get_science_packs(tech_name)
    if not tech_raw[tech_name] then
        log("Технология '"..tech_name.."' не найдена")
        return nil
    end

    if not tech_raw[tech_name].unit or not tech_raw[tech_name].unit.ingredients then
        return {}
    end

    -- Нормализуем для чтения (но не изменяем оригинал)
    local ingredients = normalize_ingredients(tech_raw[tech_name].unit.ingredients)
    local result = {}

    for _, ingredient in ipairs(ingredients) do
        table.insert(result, {
            name = ingredient.name,
            amount = ingredient.amount
        })
    end

    return result
end
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
    -- Полная замена научного пакета во всей игре с дублированием рецепта и скрытием старого
-- ----------------------------------------------------------------------------------------------
-- @param old_pack string - Название заменяемого пакета ("automation-science-pack")
-- @param new_pack string - Название нового пакета ("CTD-scientific-analyzer-grey")
function CTDmod.lib.tech.replace_science_pack_globally(old_pack, new_pack)
    local replacements = 0

    -- 0. Проверяем что новый пакет существует
    if not item_exists(new_pack) then
        error("Новый научный пакет '"..new_pack.."' не найден!")
    end

    if not item_exists(old_pack) then
        error("Старый научный пакет '"..old_pack.."' не найден!")
    end

    -- 0.1. Дублируем рецепт старого пакета для нового
    local old_recipe = data.raw.recipe[old_pack]
    if old_recipe and not data.raw.recipe[new_pack] then
        local new_recipe = util.table.deepcopy(old_recipe)
        new_recipe.name = new_pack

        -- Полностью пересоздаем результаты рецепта для нового пакета
        new_recipe.result = nil
        new_recipe.result_count = nil

        -- Создаем правильную структуру results для нового пакета
        if old_recipe.results then
            new_recipe.results = {}
            for _, result in ipairs(old_recipe.results) do
                local new_result = util.table.deepcopy(result)
                if new_result.name == old_pack then
                    new_result.name = new_pack
                elseif type(new_result) == "table" and new_result[1] == old_pack then
                    new_result[1] = new_pack
                end
                table.insert(new_recipe.results, new_result)
            end
        else
            -- Создаем простой результат для нового пакета
            new_recipe.results = {{type = "item", name = new_pack, amount = 1}}
        end

        -- Убедимся, что нет конфликтующих полей
        new_recipe.main_product = nil

        -- Обновляем локализацию
        new_recipe.localised_name = {"recipe-name."..new_pack}
        new_recipe.localised_description = {"recipe-description."..new_pack}

        -- Обновляем технологию разблокировки если есть
        if new_recipe.technology == old_pack then
            new_recipe.technology = new_pack
        end

        data:extend({new_recipe})
        log("Создан рецепт для '"..new_pack.."' на основе '"..old_pack.."'")
    end

    -- 0.2. Дублируем технологию разблокировки если нужно
    local old_tech = tech_raw[old_pack]
    if old_tech and not tech_raw[new_pack] then
        local new_tech = util.table.deepcopy(old_tech)
        new_tech.name = new_pack
        new_tech.localised_name = {"technology-name."..new_pack}
        new_tech.localised_description = {"technology-description."..new_pack}

        -- Обновляем эффекты разблокировки
        if new_tech.effects then
            for _, effect in ipairs(new_tech.effects) do
                if effect.type == "unlock-recipe" and effect.recipe == old_pack then
                    effect.recipe = new_pack
                end
            end
        end

        -- Нормализуем ингредиенты
        if new_tech.unit and new_tech.unit.ingredients then
            new_tech.unit.ingredients = normalize_ingredients(new_tech.unit.ingredients)
        end

        data:extend({new_tech})
        log("Создана технология для '"..new_pack.."' на основе '"..old_pack.."'")
    end

    -- 0.3. Правильно скрываем старый пакет, рецепт и технологию
    if data.raw.tool and data.raw.tool[old_pack] then
        data.raw.tool[old_pack].subgroup = "hidden"
        data.raw.tool[old_pack].hidden = true
        data.raw.tool[old_pack].order = "zzz"
    elseif data.raw.item and data.raw.item[old_pack] then
        data.raw.item[old_pack].subgroup = "hidden"
        data.raw.item[old_pack].hidden = true
        data.raw.item[old_pack].order = "zzz"
    end

    if data.raw.recipe[old_pack] then
        data.raw.recipe[old_pack].enabled = false
        data.raw.recipe[old_pack].hidden = true
        data.raw.recipe[old_pack].subgroup = "hidden"
        data.raw.recipe[old_pack].order = "zzz"
    end

    if tech_raw[old_pack] then
        tech_raw[old_pack].hidden = true
        tech_raw[old_pack].enabled = false
    end

    -- Функция замены в ингредиентах (Factorio 2.0+)
    local function replace_in_ingredients(ingredients)
        if not ingredients then return nil, 0 end

        local normalized = normalize_ingredients(ingredients)
        local local_replacements = 0

        for _, ing in ipairs(normalized) do
            if ing.name == old_pack then
                ing.name = new_pack
                local_replacements = local_replacements + 1
                replacements = replacements + 1
            end
        end

        return normalized, local_replacements
    end

    -- 1. Замена в технологиях
    for tech_name, tech in pairs(tech_raw) do
        if tech.unit and tech.unit.ingredients then
            local new_ingredients, count = replace_in_ingredients(tech.unit.ingredients)
            tech.unit.ingredients = new_ingredients
        end

        -- Заменяем в зависимостях технологий
        if tech.prerequisites then
            for i, prereq in ipairs(tech.prerequisites) do
                if prereq == old_pack then
                    tech.prerequisites[i] = new_pack
                    replacements = replacements + 1
                end
            end
        end
    end

    -- 2. Замена в рецептах (только как ингредиенты)
    for recipe_name, recipe in pairs(data.raw.recipe) do
        -- Пропускаем рецепты, которые производят научные пакеты
        if recipe_name ~= old_pack and recipe_name ~= new_pack then
            -- Обычные рецепты
            if recipe.ingredients then
                local new_ingredients, _ = replace_in_ingredients(recipe.ingredients)
                recipe.ingredients = new_ingredients
            end
        end

        -- Заменяем технологию разблокировки
        if recipe.technology == old_pack then
            recipe.technology = new_pack
            replacements = replacements + 1
        end
    end

    -- 3. Замена в лабораториях
    for lab_name, lab in pairs(data.raw["lab"]) do
        if lab.inputs then
            local new_inputs, _ = replace_in_ingredients(lab.inputs)
            lab.inputs = new_inputs
        end
    end

    -- 4. Замена в других сущностях (только где есть ингредиенты)
    for category_name, category in pairs(data.raw) do
        for entity_name, entity in pairs(category) do
            if entity.ingredients then
                local new_ingredients, _ = replace_in_ingredients(entity.ingredients)
                entity.ingredients = new_ingredients
            end
        end
    end

    -- 5. Замена в эффектах технологий
    for tech_name, tech in pairs(tech_raw) do
        if tech.effects then
            for _, effect in ipairs(tech.effects) do
                if effect.type == "unlock-recipe" and effect.recipe == old_pack then
                    effect.recipe = new_pack
                    replacements = replacements + 1
                end
            end
        end
    end

    -- 6. Создаем подгруппу "hidden" если ее нет
    if not data.raw["item-subgroup"]["hidden"] then
        data:extend({
            {
                type = "item-subgroup",
                name = "hidden",
                group = "other",
                order = "zzz"
            }
        })
    end

    log("Глобальная замена: "..replacements.." вхождений научного пакета '"..old_pack.."' на '"..new_pack.."'")
    return true
end
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
    -- Удаляет эффект разблокировки конкретного рецепта из технологии
-- ----------------------------------------------------------------------------------------------
-- @param tech_name string - Название технологии
-- @param recipe_name string - Название рецепта для удаления из эффектов
-- @return boolean - Успешно ли выполнено удаление
function CTDmod.lib.tech.remove_recipe_effect(tech_name, recipe_name)
    -- Проверяем существование технологии
    if not tech_raw[tech_name] then
        error("Технология '"..tech_name.."' не найдена!")
    end

    -- Проверяем наличие эффектов
    if not tech_raw[tech_name].effects then
        log("У технологии '"..tech_name.."' нет эффектов для удаления")
        return false
    end

    -- Ищем и удаляем эффект разблокировки указанного рецепта
    local found = false
    for i = #tech_raw[tech_name].effects, 1, -1 do
        local effect = tech_raw[tech_name].effects[i]
        if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
            table.remove(tech_raw[tech_name].effects, i)
            found = true
            log("Удален эффект разблокировки рецепта '"..recipe_name.."' из технологии '"..tech_name.."'")
            break -- Удаляем только первое вхождение
        end
    end

    -- Если эффектов не осталось, удаляем пустую таблицу
    if #tech_raw[tech_name].effects == 0 then
        tech_raw[tech_name].effects = nil
        log("Все эффекты удалены из технологии '"..tech_name.."'")
    end

    if not found then
        log("Эффект разблокировки рецепта '"..recipe_name.."' не найден в технологии '"..tech_name.."'")
        return false
    end

    return true
end
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
    -- Удаляет несколько эффектов разблокировки рецептов из технологии
-- ----------------------------------------------------------------------------------------------
-- @param tech_name string - Название технологии
-- @param recipe_names table - Таблица названий рецептов для удаления
-- @return boolean - Успешно ли выполнено удаление
function CTDmod.lib.tech.remove_recipe_effects(tech_name, recipe_names)
    if not tech_raw[tech_name] then
        error("Технология '"..tech_name.."' не найдена!")
    end

    local removed_count = 0

    if not tech_raw[tech_name].effects then
        log("У технологии '"..tech_name.."' нет эффектов для удаления")
        return false
    end

    -- Создаем таблицу для быстрого поиска
    local recipes_to_remove = {}
    for _, recipe_name in ipairs(recipe_names) do
        recipes_to_remove[recipe_name] = true
    end

    -- Удаляем эффекты
    for i = #tech_raw[tech_name].effects, 1, -1 do
        local effect = tech_raw[tech_name].effects[i]
        if effect.type == "unlock-recipe" and recipes_to_remove[effect.recipe] then
            table.remove(tech_raw[tech_name].effects, i)
            removed_count = removed_count + 1
            log("Удален эффект разблокировки рецепта '"..effect.recipe.."' из технологии '"..tech_name.."'")
        end
    end

    -- Если эффектов не осталось, удаляем пустую таблицу
    if tech_raw[tech_name].effects and #tech_raw[tech_name].effects == 0 then
        tech_raw[tech_name].effects = nil
    end

    log("Удалено "..removed_count.." эффектов из технологии '"..tech_name.."'")
    return removed_count > 0
end
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
    -- Получает все эффекты разблокировки рецептов из технологии
-- ----------------------------------------------------------------------------------------------
-- @param tech_name string - Название технологии
-- @return table - Таблица рецептов или nil
function CTDmod.lib.tech.get_recipe_effects(tech_name)
    if not tech_raw[tech_name] then
        error("Технология '"..tech_name.."' не найдена!")
    end

    local recipes = {}

    if tech_raw[tech_name].effects then
        for _, effect in ipairs(tech_raw[tech_name].effects) do
            if effect.type == "unlock-recipe" then
                table.insert(recipes, effect.recipe)
            end
        end
    end

    return recipes
end
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
    -- Проверяет содержит ли технология эффект разблокировки конкретного рецепта
-- ----------------------------------------------------------------------------------------------
-- @param tech_name string - Название технологии
-- @param recipe_name string - Название рецепта
-- @return boolean - Содержит ли технология эффект
function CTDmod.lib.tech.has_recipe_effect(tech_name, recipe_name)
    if not tech_raw[tech_name] then
        error("Технология '"..tech_name.."' не найдена!")
    end

    if tech_raw[tech_name].effects then
        for _, effect in ipairs(tech_raw[tech_name].effects) do
            if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
                return true
            end
        end
    end

    return false
end
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
    -- Удаляет научный пакет 2 из технологий, где присутствует научный пакет 1
-- ----------------------------------------------------------------------------------------------
-- @param search_pack string - Научный пакет для поиска (если найден, удаляем remove_pack)
-- @param remove_pack string - Научный пакет для удаления
-- @return table - Список технологий, где была выполнена замена
function CTDmod.lib.tech.remove_science_pack_if_another_exists(search_pack, remove_pack)
    local modified_techs = {}

    -- Проверяем что оба пакета существуют
    if not item_exists(search_pack) then
        error("Научный пакет для поиска '"..search_pack.."' не найден!")
    end

    if not item_exists(remove_pack) then
        error("Научный пакет для удаления '"..remove_pack.."' не найден!")
    end

    -- Проходим по всем технологиям
    for tech_name, tech in pairs(tech_raw) do
        if tech.unit and tech.unit.ingredients then
            -- Нормализуем ингредиенты
            local ingredients = normalize_ingredients(tech.unit.ingredients)
            local has_search_pack = false
            local has_remove_pack = false

            -- Проверяем наличие обоих пакетов
            for _, ing in ipairs(ingredients) do
                if ing.name == search_pack then
                    has_search_pack = true
                end
                if ing.name == remove_pack then
                    has_remove_pack = true
                end
                if has_search_pack and has_remove_pack then
                    break
                end
            end

            -- Если найден search_pack И присутствует remove_pack - удаляем remove_pack
            if has_search_pack and has_remove_pack then
                local new_ingredients = {}
                local removed = false

                for _, ing in ipairs(ingredients) do
                    if ing.name == remove_pack then
                        removed = true
                    else
                        table.insert(new_ingredients, ing)
                    end
                end

                if removed then
                    tech.unit.ingredients = new_ingredients
                    table.insert(modified_techs, tech_name)
                    log("Удален пакет '"..remove_pack.."' из технологии '"..tech_name.."' (найден пакет '"..search_pack.."')")
                end
            end
        end
    end

    log("Обработано технологий: "..#modified_techs..", удален пакет '"..remove_pack.."' где присутствует '"..search_pack.."'")
    return modified_techs
end
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
    -- Удаляет научный пакет 2 из технологий, где НЕ присутствует научный пакет 1
-- ----------------------------------------------------------------------------------------------
-- @param search_pack string - Научный пакет для поиска (если НЕ найден, удаляем remove_pack)
-- @param remove_pack string - Научный пакет для удаления
-- @return table - Список технологий, где была выполнена замена
function CTDmod.lib.tech.remove_science_pack_if_another_not_exists(search_pack, remove_pack)
    local modified_techs = {}

    -- Проверяем что оба пакета существуют
    if not item_exists(search_pack) then
        error("Научный пакет для поиска '"..search_pack.."' не найден!")
    end

    if not item_exists(remove_pack) then
        error("Научный пакет для удаления '"..remove_pack.."' не найден!")
    end

    -- Проходим по всем технологиям
    for tech_name, tech in pairs(tech_raw) do
        if tech.unit and tech.unit.ingredients then
            -- Нормализуем ингредиенты
            local ingredients = normalize_ingredients(tech.unit.ingredients)
            local has_search_pack = false
            local has_remove_pack = false

            -- Проверяем наличие пакетов
            for _, ing in ipairs(ingredients) do
                if ing.name == search_pack then
                    has_search_pack = true
                end
                if ing.name == remove_pack then
                    has_remove_pack = true
                end
            end

            -- Если НЕ найден search_pack И присутствует remove_pack - удаляем remove_pack
            if not has_search_pack and has_remove_pack then
                local new_ingredients = {}
                local removed = false

                for _, ing in ipairs(ingredients) do
                    if ing.name == remove_pack then
                        removed = true
                    else
                        table.insert(new_ingredients, ing)
                    end
                end

                if removed then
                    tech.unit.ingredients = new_ingredients
                    table.insert(modified_techs, tech_name)
                    log("Удален пакет '"..remove_pack.."' из технологии '"..tech_name.."' (отсутствует пакет '"..search_pack.."')")
                end
            end
        end
    end

    log("Обработано технологий: "..#modified_techs..", удален пакет '"..remove_pack.."' где отсутствует '"..search_pack.."'")
    return modified_techs
end
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
    -- Заменяет научный пакет 2 на пакет 3 в технологиях, где присутствует научный пакет 1
-- ----------------------------------------------------------------------------------------------
-- @param search_pack string - Научный пакет для поиска (условие)
-- @param old_pack string - Научный пакет для замены
-- @param new_pack string - Новый научный пакет
-- @return table - Список технологий, где была выполнена замена
function CTDmod.lib.tech.replace_science_pack_if_another_exists(search_pack, old_pack, new_pack)
    local modified_techs = {}

    -- Проверяем что все пакеты существуют
    if not item_exists(search_pack) then
        error("Научный пакет для поиска '"..search_pack.."' не найден!")
    end

    if not item_exists(old_pack) then
        error("Научный пакет для замены '"..old_pack.."' не найден!")
    end

    if not item_exists(new_pack) then
        error("Новый научный пакет '"..new_pack.."' не найден!")
    end

    -- Проходим по всем технологиям
    for tech_name, tech in pairs(tech_raw) do
        if tech.unit and tech.unit.ingredients then
            -- Нормализуем ингредиенты
            local ingredients = normalize_ingredients(tech.unit.ingredients)
            local has_search_pack = false
            local has_old_pack = false

            -- Проверяем наличие пакетов
            for _, ing in ipairs(ingredients) do
                if ing.name == search_pack then
                    has_search_pack = true
                end
                if ing.name == old_pack then
                    has_old_pack = true
                end
                if has_search_pack and has_old_pack then
                    break
                end
            end

            -- Если найден search_pack И присутствует old_pack - заменяем old_pack на new_pack
            if has_search_pack and has_old_pack then
                local replaced = false

                for _, ing in ipairs(ingredients) do
                    if ing.name == old_pack then
                        ing.name = new_pack
                        replaced = true
                    end
                end

                if replaced then
                    tech.unit.ingredients = ingredients
                    table.insert(modified_techs, tech_name)
                    log("Заменен пакет '"..old_pack.."' на '"..new_pack.."' в технологии '"..tech_name.."' (найден пакет '"..search_pack.."')")
                end
            end
        end
    end

    log("Обработано технологий: "..#modified_techs..", заменен пакет '"..old_pack.."' на '"..new_pack.."' где присутствует '"..search_pack.."'")
    return modified_techs
end
-- ----------------------------------------------------------------------------------------------

-- ##############################################################################################
log("Библиотека CTDmod.lib.tech успешно загружена")
-- ----------------------------------------------------------------------------------------------