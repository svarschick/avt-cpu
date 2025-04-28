// значения для rom
// 0x0 - 0x0000 - константа 0
// 0x1 - 0x0001 - константа 1
// 0x2 - 0x8000 - битовая  маска для знака
// 0x3 - 0x7C00 - битовая маска для экспоненты
// 0x4 - 0x03FF - битовая маска для мантиссы
// 0x5 - 0x7FFF - битовая маска дял экспоненты и мантиссы
// 0x6 - 0x000A - нормальное значение для экспоненты
// 0x7 - 0x000B - максимальное значение для экспоненты, если на каждом шаге происходило переполнение
// 0x8 - 0x000F - сдвиг порядков для экспоненты ( = 15 )
// 0x9 - 0x0400 - бит по умолчанию для мантиссы
// 0xA - 0xFFE0 - маска для проверки переполнения мантиссы
// 0xB - 0x0800 - маска проверки переполнения мантиссы
// 0xC - 0xFFFF - максимальное значение регистра
// 0xD - 0x0020 - переполнение для экспоненты

// ввод номера операции
// 0 - НОК
// 1 - возведение числа в квадрат в экспоненциальном виде
inp rga 0xF
rom 0x1
cmp rga rmv
jme sqr
jmp nok

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

nok:
    // информация о регистрах (скорее всего уже неверная):
    // rga - регистр с первым числом. тут же будет сохранён НОД
    // rgb - регистр со вторым числом
    // rgc - счётчик
    // rgd - регистр для счёта числа сдвигов
    // rge - регистр с перемноженными числами из rga и rgb
    // rgf - регистр для сдвига числа при умножении

    // информация об ошибках
    // 0x0 - всё гуд
    // 0x1 - переполнение
    // 0x2 - один из операндов равен нулю

    inp rga 0xF // ввод первого числа
    inp rgb 0xF // ввод второго числа

    // проверка на ноль
    rom 0x0 // 0x0000
    cmp rga rmv
    jme err_0x2
    cmp rgb rmv
    jme err_0x2


    // числа даны в дополнительном коде, поэтому делаем проверку на отрицательное число. если да, то берём его модуль
    rom 0x2 // 0x8000 - проверка на максимальное отрицательное число
    cmp rga rmv
    jme err_0x1
    cmp rgb rmv
    jme err_0x1

    // число в rga по модулю
    rom 0x2 // 0x8000
    and rga rmv
    cmp rgk rmv
    jme add1_rga

    // число в rgb по модулю
    check_modul_rgb:
        rom 0x2 // 0x8000
        and rgb rmv
        cmp rgk rmv
        jme add1_rgb
        jmp prepare_multiply

    add1_rga:
        not rga
        mov rga rgk
        rom 0x1 // 0x0001
        add rga rmv
        mov rga rgk
        jmp check_modul_rgb

    add1_rgb:
        not rgb
        mov rgb rgk
        rom 0x1 // 0x0001
        add rgb rmv
        mov rgb rgk
        jmp prepare_multiply

    // -----> умножение регистров <-----
    prepare_multiply:
        // подготовка регистров для сдвигов
        mov rgd rga
        mov rge rgb

    multiply:
        // умножаем столбиком. для этого каждый раз делаем проверку на ноль для второго операнда, так как его мы будем двигать
        // rga - первый операнд, rgb - второй операнд, rgc - результат умножения, rgd - регистр для сдвига первого операнда влево, 
        // rge - регистр для сдвига второго операнда вправо
        
        // проверка на завершение умножения
        rom 0x0 // 0x0000
        cmp rge rmv
        jme end_multiply

        // проверяем необходимость добавлять число на текущем шаге итерации
        rom 0x1 // 0x0001
        and rge rmv
        cmp rgk rmv
        jme add_multiply
        jmp finalize_multiply

        add_multiply:
            add rgc rgd
            jmo err_0x1 // произошло переполнение
            mov rgc rgk

        finalize_multiply:
            shl rgd
            shr rge
        jmp multiply

    end_multiply:
    jmp nod

    // ошибка: переполнение регистра
    err_0x1:
        err 0x1
        fin
    // ошибка: один из операндов равен нулю
    err_0x2:
        err 0x2
        fin

    nod:
        // -----> вычисление НОД по алгоритму Евклида через вычитание <-----
        cmp rga rgb
        jme end_nod
        cmp rga rgb
        jml rgb_more
        sub rga rgb
        mov rga rgk
        jmp nod
        rgb_more:
            sub rgb rga
            mov rgb rgk
        jmp nod

    end_nod:

    // -----> деление без восстановления остатка <-----
    // делим число rga - nod на rgc - результат умножения
    // сбрасываем все регистры на всякий случай
    rom 0x0 // 0x0000
    mov rgb rmv
    mov rgd rmv
    mov rge rmv
    mov rgf rmv

    // rgb - расширение делимого, rgc - делимое оригинальное, rga - делитель оригинальный, rgd - отрицательный делитель, rge - результат
    // rgf - счётчик числа операций для деления

    // устанавливаем счётчик
    rom 0x8 // 0x000F
    mov rgf rmv

    not rga
    mov rgd rgk
    rom 0x1 // 0x0001
    add rgd rmv
    mov rgd rgk

    div:
        // устанавливаем флаг для rgb
        shl rgb // сдвиг расширенного делимого
        rom 0x2 // 0x8000
        and rgc rmv
        cmp rgk rmv
        shl rgc // сдвиг оригинального делимого
        jme positive_add
        jmp add_divisor

        // добавляем 1 к расширенному делимому
        positive_add:
            rom 0x1 // 0x0001
            add rgb rmv
            mov rgb rgk

        // добавлем делитель 
        add_divisor:
            shl rge // переполнение может произойти, тогда добавим 1, а пока записываем 0 в результат

            // устанавливаем флаг для добавления положительного или отрицательного делителя
            rom 0x2 // 0x8000
            and rgb rmv
            cmp rgk rmv
            jne add_negative

            // добавляем положительное делимое
            add rgb rga
            jmo set_one // произошло переполнение. записываем 1 в результат
            mov rgb rgk
            jmp for_cycle

            // добавляем отрицательное делимое
            add_negative:
                add rgb rgd
                jmo set_one // произошло переполнение. записываем 1 в результат
                mov rgb rgk
                jmp for_cycle

            set_one:
                rom 0x1 // 0x0001
                add rge rmv
                mov rge rgk

        // считаем количество итераций до 0, так как надо 16 итераций, 1 итерацию уже сделали, осталось 15
        for_cycle:
            rom 0x0 // 0x0000
            cmp rgf rmv
            jme end_div
            rom 0x1 // 0x0001
            sub rgf rmv
            mov rgf rgk
            jmp div

    end_div:
        // записываем результат деления в rga
        mov rga rge
        fin

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

sqr:
    // значения для rom
    // 0x0 - 0x0000 - константа 0
    // 0x1 - 0x0001 - константа 1
    // 0x2 - 0x8000 - битовая  маска для знака
    // 0x3 - 0x7C00 - битовая маска для экспоненты
    // 0x4 - 0x03FF - битовая маска для мантиссы
    // 0x5 - 0x7FFF - битовая маска дял экспоненты и мантиссы
    // 0x6 - 0x000A - нормальное значение для экспоненты
    // 0x7 - 0x000B - максимальное значение для экспоненты, если на каждом шаге происходило переполнение
    // 0x8 - 0x000F - сдвиг порядков для экспоненты ( = 15 )
    // 0x9 - 0x0400 - бит по умолчанию для мантиссы
    // 0xA - 0xFFE0 - маска для проверки переполнения мантиссы
    // 0xB - 0x0800 - маска проверки переполнения мантиссы
    // 0xC - 0xFFFF - максимальное значение регистра
    // 0xD - 0x0020 - переполнение для экспоненты

    inp rga 0xF // ввод числа в формате половинной точности
    rom 0x3     // 0x7C00
    and rga rmv
    cmp rgk rmv
    jne not_special

    // ----->   проверка специальных случаев   <-----
    // проверка на NaN
    rom 0x4 // 0x03FF
    and rga rmv
    rom 0x0 // 0x0000
    cmp rgk rmv
    jne is_nan

    // результатом является +inf
    inf:
        rom 0x3     // 0x7C00
        mov rga rmv
        fin

    is_nan:
        rom 0x5 // 0x7FFF
        mov rga rmv
        err 0x1 // установка кода ошибки для NaN
        fin

    // ----------->   основная обработка   <-----------
    // rga - оригинальное число, rgb - экспонента, rgc - мантисса, rgd - регистр для сдвига первого операнда влево при умножении, 
    // rge - регистр для сдвига второго операнда вправо, rgf - регистр для единицы округления
    not_special:
        // сначала вычисляем мантиссу. все необходимые действия по нормализации будем производить после.
        // если при перемножении мантисс получается, что число превышает допустимые лимиты, то делаем сдвиг.

        // вырезаем мантиссу и экспоненту
        rom 0x3 // 0x7C00
        and rga rmv
        mov rgb rgk
        rom 0x4 // 0x03FF
        and rga rmv
        mov rgc rgk

        // добавляем скрытый бит
        rom 0x0 // 0x0000
        cmp rgb rmv
        jme skip_add_hidden_bit

        rom 0x9 // 0x0400
        or  rgc rmv
        mov rgc rgk

        skip_add_hidden_bit:
            // подготовка к умножению
            mov rgd rgc
            mov rge rgc
            // обнуляем мантиссу
            rom 0x0 // 0x0000
            mov rgc rmv
            // обнуляем экспоненту
            mov rgb rmv

        mantiss_multiply:
            // умножаем столбиком. для этого каждый раз делаем проверку на ноль для второго операнда, так как его мы будем двигать
            // если вышли за рамки умножения (то есть дальше скрытого бита), то делаем сдвиг вправо всех регистров и вычитаем 1 из экспоненты

            // проверка на завершение умножения
            rom 0x0 // 0x0000
            cmp rge rmv
            jme end_mantiss_multiply

            // проверяем необходимость добавлять число на текущем шаге итерации
            rom 0x1 // 0x0001
            and rge rmv
            cmp rgk rmv
            jme add_mantiss_multiply
            jmp finalize_mantiss_multiply

            add_mantiss_multiply:
                add rgc rgd
                mov rgc rgk
                jmp finalize_mantiss_multiply

            mantiss_multiply_overflow:
                // сохраняем единицу для округления
                rom 0x1 // 0x0001
                and rgc rmv
                mov rgf rgk

                // при переполнении сдвигаем регистры вправо и добавляем к экспоненте 1
                shr rgc
                shr rgd
                rom 0x1 // 0x0001
                add rgb rmv
                mov rgb rgk

            finalize_mantiss_multiply:
                // проверка на переполнение при сдвиге
                rom 0xB // 0x0800
                cmp rmv rgd // для числа, на которое умножаем
                jml mantiss_multiply_overflow

                shl rgd
                shr rge
            jmp mantiss_multiply

        end_mantiss_multiply:
            // добавляем 1 для округления результата, если не было переполнения мантиссы
            // если было переполнение, то нужно округлить мантиссу с учётом этой единицы
            // проверяем на переполнение мантиссы
            rom 0xB // 0x0800
            and rgc rmv // для результата умножения
            cmp rgk rmv
            jne without_overflow_mantissa

            // если было переполнение
            rom 0x1 // 0x0001
            and rgc rmv
            mov rgf rmv
            add rgc rgf
            mov rgc rgk
            
            // сдвиг мантиссы вправо, добавляем 1 к экспоненте за этот сдвиг
            rom 0x1 // 0x0001
            add rgb rmv
            mov rgb rgk
            shr rgc
            jmp exp

            without_overflow_mantissa:
                add rgc rgf
                mov rgc rgk

        // -----> считаем экспоненту <-----
        exp:
            // нормализуем мантиссу и экспоненту. для посчитанной экспоненты нормальным значением является 10 - 0x000A. 
            // максимально возможное - 11 - 0x000B, минимально возможное - 0 - 0x0000
            // если в результате из финального значения экспоненты вычесть 10, то получем конечный результат, если там было 11
            // если там было меньше, то выполним денормализацию позже
            
            // вырезаем экспоненту
            rom 0x3 // 0x7C00
            and rga rmv
            mov rgd rgk

            // выравниваем экспоненту для вычислений. rgf - счётчик
            rom 0x6 // 0x000A
            mov rgf rmv
            rshift_exp_loop:
                rom 0x0 // 0x0000
                cmp rgf rmv
                jme end_rshift_exp_lopp
                shr rgd
                rom 0x1 // 0x0001
                sub rgf rmv
                mov rgf rgk
                jmp rshift_exp_loop
            end_rshift_exp_lopp:
            // удвоение изначальной экспоненты
            add rgd rgd 
            mov rgd rgk

            // вычитаем сдвиг экспоненты
            rom 0x8 // 0x000F
            sub rgd rmv
            mov rgd rgk

            // добавляем результирующую экспоненту после умножения
            add rgd rgb
            mov rgd rgk

            // вычитаем сдвиг для нормализованной экспоненты
            rom 0x6 // 0x000A
            sub rgd rmv
            mov rgd rgk

            // проверка на положительное значение экспоненты. если она отрицательная, 
            // то проводим нормализацию до тех пор, пока не получим нулевую экспоненту
            rom 0x2 // 0x8000
            and rgd rmv
            cmp rgk rmv
            jme normalize
            
            skip_denormal_shift:
            // проверка на переполнение экспоненты. результатом будет +inf
            rom 0xD // 0x0020
            and rgd rmv
            cmp rmv rgk
            jme inf
            
            brk
            // безусловный сдвиг вправо для экспоненты, если вид экспоненты денормализованный????????
            rom 0x0 // 0x0000
            cmp rgd rmv
            jne skip_shift
            shr rgc

            skip_shift:

            // задвигаем экспоненту обратно. 
            lshift_exp:
                rom 0x0 // 0x0000
                mov rgf rmv
                rom 0x6 // 0x000A
                mov rgf rmv
                lshift_exp_loop:
                    rom 0x0 // 0x0000
                    cmp rgf rmv
                    jme end_lshift_exp_lopp
                    shl rgd
                    rom 0x1 // 0x0001
                    sub rgf rmv
                    mov rgf rgk
                    jmp lshift_exp_loop
                end_lshift_exp_lopp:
                jmp finalize

    finalize:
        // финальная проверка на переполнение экспоненты
        rom 0x3 // 0x7C00
        cmp rgd rmv
        jme inf

        // обрезаем мантиссу
        rom 0x4 // 0x03FF
        and rgc rmv
        mov rgc rgk

        // собираем результат
        rom 0x0 // 0x0000
        mov rga rmv
        or  rgd rgc
        mov rga rgk
        fin

    normalize:
        brk

        normalize_loop:
            // двигаем мантиссу до тех пор, пока экспонента не станет нулём
            rom 0x0 // 0x0000
            cmp rgd rmv
            jme end_normalize_loop
        
            rom 0x1 // 0x0001
            add rgd rmv
            mov rgd rgk

            // сохраняем последний бит для округления
            and rgc rmv
            mov rgf rgk
            shr rgc

            jmp normalize_loop

        end_normalize_loop:
            // добавляем округляющую единицу
            add rgc rgf
            mov rgc rgk

            // двигаем на 1 разряд, так как число денормализованное ( с округлением?! )?????????
            rom 0x1
            and rgc rmv
            mov rgf rgk
            add rgc rgf
            mov rgc rgk
            shr rgc
            jmp finalize

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////