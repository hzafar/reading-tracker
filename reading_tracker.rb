#!/usr/bin/ruby1.9.1

require 'rethinkdb'
require 'sinatra'

r = RethinkDB::RQL.new
Connection = r.connect(:host => 'localhost', :port => 28015, :db => 'litdb')

get '/' do
    erb :mainpage
end

get '/add/book' do
    erb :addbook
end

post '/add/book' do
    if params['isbn'].empty? || params['title'].empty? || params['author'].empty?
        halt 'Cannot specify empty values for any of title, author, or ISBN!'
    else
        r.table('books').insert({'isbn' => params['isbn'],
                                 'title' => params['title'],
                                 'author' => params['author']},
                                { 'conflict' => 'update' }).run(Connection)
        redirect to('/')
    end
end

get '/add/sections' do
    @books = r.table('books').with_fields('title', 'isbn').run(Connection)
    @next = '/add/sections/next'
    erb :choosebook
end

post '/add/sections/next' do
    @book = r.table('books').get(params['isbn']).run(Connection)
    p @book
    erb :addsections
end

post '/add/sections/finished' do 
    sections = Array.new
    params['sections'].each_line { |s|
        sections << { 'name' => s.strip,
                      'book' => params['isbn']
                    }
    }

    r.table('sections').insert(sections).run(Connection)
        
    redirect to('/')
end

get '/add/notes' do
    @books = r.table('books').with_fields('title', 'isbn').run(Connection)
    @next = '/add/notes/next'
    erb :choosebook
end

post '/add/notes/next' do
    @book = r.table('books').get(params['isbn']).merge(
        { 'sections' =>
            r.table('sections').filter { |document|
                document['book'].eq(params['isbn'])
            }.coerce_to('array')
        }).run(Connection)

    erb :addnotes
end

post '/add/notes/finished' do
    r.table('finished').insert({ 'notes' => params['notes'],
                                       'section_id' => params['section'],
                                       'timestamp' => r.now()
                                     }).run(Connection)

    redirect to('/')
end

get '/view/progress' do
    @data = r.table('books').map { |book|
        { 'book' => book,
          'sections' =>
            r.table('sections').filter {
                |section| section['book'].eq(book['isbn'])
            }.map { |s|
                {   'section' => s, 
                    'notes' => r.table('finished').get_all(
                        s['id'], {index: 'section_id'}
                    ).coerce_to('array')
                }
            }.coerce_to('array')
        }
    }.run(Connection)

    erb :progress
end
