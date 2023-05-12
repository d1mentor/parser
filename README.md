# English

# Parsergemv 0.1

The gem is intended for copying and automatically integrating the front-end of the target site into Rails. It is also possible to automatically translate site pages, and create a multilingual site structure in Rails.

Runtime versions tested:
Ruby 3.0.0
Rails 7.0.4.3

## Installation

Install the gem and add it to the Gemfile:

     $ bundle add parsergem

If you are not using bundler, you can install the gem like this:

     $ gem install parsergem

## Usage

It is important that the target site meets certain requirements:
1) The presence of a sitemap, at "target.com/sitemap.xml"
2) If you need to make language versions, the target site must be monolingual

At this stage, the gem provides one generator to perform the declared functions.
After installing the gem, run the generator:

     $ rails g parser_gem:test --target-url "target.com"

The generator takes the following parameters:
     For normal cloning:
         `--target_url` - Domain name of the target site
     To template the header and footer of the site:
         `--header_class_name` - ID of the block in which the header is located
         `--footer_class_name` - ID of the block containing the footer
     To create language versions (You must fill in all parameters):
         `--target_site_language` - Current site language
         `--languages` - "en es de" format string, with a list of language codes to which the original site should be translated
         `--aws_region` - AWS Region
         `--aws_public_key` - The public key of your AWS TRANSLATE API
         `--aws_secret_key` - The secret key of your AWS TRANSLATE API

After the generator has finished its work, you will most likely need to modify the header and footer parshals to fix the links.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/d1mentor/parser.

# Russian

# Parsergem v 0.1

Гем предназначен для копирования и автоматической интеграции в Rails фронтенда целевого сайта. Так-же есть возможность автоматического перевода страниц сайта, и создания в Rails структуры мультиязычного сайта.

Проверенные версии среды выполнения:
Ruby 3.0.0
Rails 7.0.4.3

## Установка

Установить гем и добавить его в Gemfile:

    $ bundle add parsergem

Если вы не используете bundler, установить гем можно так:

    $ gem install parsergem 

## Использование

Важно, что-бы целевой сайт соответствовал некоторым требованиям:
1) Наличие карты сайта, по адресу "target.com/sitemap.xml"
2) Если необходимо сделать языковые версии, целевой сайт должен быть моноязычным

На данном этапе гем предоставляет один генератор, для выполнения заявленных функций.
После установки гема, запустите генератор:

    $ rails g parser_gem:test --target-url "target.com"

Генератор принимает следующие параметры:
    Для обычного клонирования:
        `--target_url` - Доменное имя целевого сайта
    Для шаблонизации хедера и футера сайта:
        `--header_class_name` - ID блока в котором находится хедер
        `--footer_class_name` - ID блока в котором находится футер
    Для создания языковых версий(Необходимо заполнить все параметры):
        `--target_site_language` - Текущий язык сайта
        `--languages` - Строка формата "en es de", с перечнем кодов языков, на которые стоит перевести оригинальный сайт
        `--aws_region` - Регион AWS
        `--aws_public_key` - Публичный ключ вашего AWS TRANSLATE API 
        `--aws_secret_key` - Секретный ключ вашего AWS TRANSLATE API

После того как генератор закончит свою работу, вам, скорее всего, придётся доработать паршалы хедеров и футеров для исправления ссылок. 

## Содействие

Сообщения об ошибках и запросы на доработку гема приветствуются на GitHub по адресу https://github.com/d1mentor/parser

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).


