
module Jeanny

    # Класс который выполнят всю основную работу. 
    # Парсит и заменяет классы, сохраняет и сравнивает их.    
    class Engine

        attr_reader :classes

        def initialize
            @classes = Dictionary.new
        end

        # Метод ищет имена классов, в переданном ему тексте
        def analyze file_meat
            
            fail TypeError, "передан неверный аргумент (Jeanny::Engine.analyze)" if file_meat.empty?

            # Удаляем все экспрешены и удаляем все что в простых и фигурных скобках
            file_meat = file_meat.remove_expressions.gsub(/\{.*?\}/m , '{}').gsub(/\(.*?\)/, '()')

            short_words = generate_short_words

            # Находим имена классов
            file_meat.gsub(/\.([^\.,\{\} :#\[\]\*\n\s\/]+)/) do |match|
                # Если найденная строка соответствует маске и класс еще не был добавлен — добавляем его
                @classes[$1] = short_words.shift if match =~ /^\.([a-z]-.+)$/ and not(@classes.include? $1 ) 
            end

            fail JeannyClassesNotFound, "похоже, что в анализируемом файле нет классов подходящих по условию" if @classes.empty?
            
            # @classes.sort!
            @classes

        end
        
        # Метод сравниваеи найденные классы с переданными в аргументе saved_classes
        # и возвращает имена элементво которых нет в saved_classes
        def compare_with saved_classes

            return if saved_classes.nil? or saved_classes.empty?
            
            saved_classes = Dictionary.new saved_classes
            
            # находим новые классы
            new_classes = ((saved_classes.keys | @classes.keys) - saved_classes.keys)

            @classes = saved_classes

            # генерируем короткие имена и удаляем из них уже используемые
            short_words = generate_short_words - saved_classes.values
            new_classes.each do |class_name|
                @classes[class_name] = short_words.shift
            end
            
            # @classes.sort!

            new_classes

        end
        
        # Метод для замены классов
        def replace data, type
            
            fail "Тип блока не понятный" unless [:js, :css, :html, :plain].include? type
            fail "nil Ololo" if data.nil?
            
            code = case type
                when :js then JSCode
                when :css then CSSCode
                when :html then HTMLCode
                when :plain then PlainCode
            end
            
            @classes.sort!
            
            code.new(data).replace @classes
            
        end

        private

        # Метод генерирует и возращает массив коротких имен.
        # По умолчанию генерируется 38471 имя. Если надо больше, добавить — легко        
        def generate_short_words again = false

            short_words = []

            %w(a aa a0 a_ a- aaa a00 a0a aa0 aa_ a_a aa- a-a a0_ a0- a_0 a-0).each do |name|
                max = name.length + 1
                while name.length < max
                    short_words << name
                    name = name.next
                end
            end

            short_words

        end

    end

    # Класс-попытка реализовать что нибудь похожее на упорядоченный хэш
    class Dictionary

        include Enumerable

        attr_reader :keys, :values

        def initialize hash = {  }
            
            @keys = [ ]
            @values = [ ]

            hash.each_pair { |key, val| append key, val } if hash.kind_of? Hash
            hash.each { |item| append item[0], item[1]  } if hash.kind_of? Array

        end

        def [](key)
            if include? key
                @values[@keys.index(key)]
            else
                nil
            end
        end

        def []=(key, value)
            if include? key
                @values[@keys.index(key)] = value
            else
                append key, value
            end
        end

        def append key, value
            @keys << key
            @values << value
        end

        def include? class_name
            @keys.include? class_name
        end

        alias :has_key? include?

        def empty?
            @keys.empty?
        end

        def each
            @keys.length.times do |i|
                yield @keys[i], @values[i]
            end
        end
        
        def sort!
            @keys.map { |x| [x, @values[@keys.index(x)]] }.sort_by { |x| x[0].length }.reverse.each_with_index do |x, i|
                @keys[i] = x[0]
                @values[i] = x[1]
            end
        end

        def select_keys_if &block
            array = []
            @keys.length.times do |i|
                need_append = yield @keys[i], @values[i]
                array << @keys[i] if need_append
            end
            array
        end

        def length
            @keys.length
        end

        def last
            unless @keys.empty?
                [@keys.last, @values.last]
            end
        end

        def to_s
            each do |key, val|
                puts key.ljust(40) + val
            end
        end
        
        def to_a
            @keys.map { |x| [x, @values[@keys.index(x)]] }
        end

    end
    
    class Code
        
        attr_reader :code
        
        def initialize code
            @code = code
        end
        
        def replace classes
            
        end
        
    end
    
    class JSCode < Code
        
        def replace classes
            
            # Находим все строки и регулярные выражения
            @code.gsub(/(("|'|\/)((\\\2|.)*?)\2)/m) do |string|

                string_before, string_after = $3, $3

                # Проходимся по всем классам
                classes.each do |full_name, short_name|

                    # И заменяем старый класс, на новый
                    string_after = string_after.gsub(full_name, short_name)
                end

                string.gsub(string_before, string_after.gsub(/(\\+)("|')/, "\\1\\1\\2"))

            end
            
        end
        
    end
    
    class CSSCode < Code
        
        def replace classes
            
            # Вырезаем экспрешены
            expression_list = []
            @code.replace_expressions! do |expression|
                # и заменяем в них классы как в js
                expression_list << JSCode.new(expression).replace(classes)
                "_ololo_#{expression_list.length}_ololo_"
            end
            
            # Вставляем экспрешены с замененными классами обратно
            expression_list.each_with_index do |expression, index|
                @code.gsub! /_ololo_#{index + 1}_ololo_/, expression
            end
            
            @code.gsub!(/\[class\^=(.*?)\]/) do |class_name|
                if classes.include? $1
                    class_name.gsub $1, classes[$1]
                else
                    class_name
                end
            end
            
            # Случайная строка
            unique_string = Time.now.object_id.to_s

            # Проходимся по классам
            classes.each do |full_name, short_name|
                
                # Заменяем старое имя класса на новое, плюс случайное число,
                # чтобы знать что этот класс мы уже изменяли
                #   TODO: Может это нахрен не надо?
                @code = @code.gsub(/\.#{full_name}(?=[^-\w])/, ".#{unique_string}#{short_name}")
            end

            # После замены имен классов, случайное число уже не нужно,
            # так что удаляем его, и возвращаем css с замененными значениями
            @code.gsub(unique_string, '')
            
        end
        
    end
    
    class HTMLCode < Code
        
        def replace classes
            
            # Заменяем классы во встроенных стилях
            @code.gsub!(/<style[^>]*?>(.*?)<\s*\/\s*style\s*>/mi) do |style|
                style.gsub($1, CSSCode.new($1).replace(classes))
            end

            # Заменяем классы во встроенных скриптах
            @code.gsub!(/<script[^>]*?>(.*?)<\s*\/\s*script\s*>/mi) do |script|
                script.gsub($1, JSCode.new($1).replace(classes))
            end
            
            # Находим аттрибуты с именем "class"
            #   TODO: Надо находить не просто "class=blablabl", а искать
            #         именно теги с аттрибутом "class"
            @code.gsub!(/class\s*=\s*('|")(.*?)\1/) do |match|
            
                # берем то что в кавычках и разбиваем по пробелам
                match = $2.split(' ')
                
                # проходимся по получившемуся массиву
                match.map! do |class_name|
                    
                    # удаляем проблелы по бокам
                    class_name = class_name.strip
                    
                    # и если в нашем списке замены есть такой класс заменяем на новое значение
                    if classes.has_key? class_name
                        classes[class_name]
                    else
                        class_name
                    end
                    # elsif class_name.eql? 'g-js'
                    #     class_name
                    # end
                    
                end.delete_if { |class_name| class_name.nil? or class_name.empty? }
                
                unless match.empty?
                    "class=\"#{match.join(' ')}\""
                else
                    ''
                    # puts match
                    # match
                end
                
            end
            
            # Находим тэги с аттрибутами в которых может быть js
            @code.gsub(/<[^>]*?(onload|onunload|onclick|ondblclick|onmousedown|onmouseup|onmouseover|onmousemove|onmouseout|onfocus|onblur|onkeypress|onkeydown|onkeyup|onsubmit|onreset|onselect|onchange)\s*=\s*("|')((\\\2|.)*?)\2[^>]*?>/mi) do |tag|
                tag.gsub($3, JSCode.new($3.gsub(/\\-/ , '-')).replace(classes))
            end
            
        end
        
    end
    
    class PlainCode < Code
        
    end

end