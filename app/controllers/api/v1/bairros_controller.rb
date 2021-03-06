class Api::V1::BairrosController < Api::V1::ApiController
  using Accentless
  
  def lista_via_cep
    bairros = []

    (13010000..13088902).each do |n|
      url = "viacep.com.br/ws/#{n.to_s}/json"
      retorno = RestClient.get(url)
      r = JSON(retorno) 
      if r['erro'].nil? 
        unless r['bairro'].nil?
          if r['localidade'] == 'Campinas'
            bairro = r['bairro']
            if bairros.index(bairro).nil?
              bairros.push(bairro)
            end
          end
        end
      end
    end

    render json: bairros
  end

  def lista    
    render json: carregar_bairros.sort
  end

  def consulta
    retorno = []
    bairros = carregar_bairros
    parametro = params[:bairro].downcase
    
    bairros.each do |bairro|   
      
      bairro_alias = Api::V1::BairrosController.alias_bairro bairro
      bairro_down = bairro.downcase
      bairro_alias.downcase!

      if parametro =~ /#{bairro_down}/ || parametro =~ /#{bairro_alias}/
        retorno.push(bairro)
      end
    end

    render json: retorno
  end

  def self.alias_bairro(bairro)
    bairro_down = bairro.downcase 
    if bairro_down =~ /jardim/
      bairro_down.sub('jardim', 'jd')
    else
      if bairro_down =~ /loteamento/
        bairro_down.sub('loteamento', 'lote')
      else
        if bairro_down =~ /parque/
          bairro_down.sub('parque', 'pq')
        else
          if bairro_down.downcase =~ /residencial/
            bairro_down.sub('residencial', 'res')
          else
            if bairro_down.downcase =~ /vila/
              bairro_down.sub('vila', 'vl')
            else
              if bairro_down.downcase =~ /conjunto/
                bairro_down.sub('conjunto', 'cj')
              else
                if bairro_down.downcase =~ /terminal intermodal de cargas/
                  bairro_down.sub('terminal intermodal de cargas', 'tic')
                else                
                  bairro_down
                end
              end
            end
          end
        end
      end
    end
  end

  def lista_lat_lng    
    render json: Api::V1::BairrosController.carregar_bairros_lat_long
  end

  def lat_lng(nome_bairro)
    retorno = {}
    bairros = Api::V1::BairrosController.carregar_bairros_lat_long
    indice = bairros.index(nome_bairro)
    retorno = bairros[indice] unless indice.nil?
  end

  def self.carregar_bairros_lat_long
    if File.exists?("bairros_lat_lng.json")
      JSON File.read("bairros_lat_lng.json")
    else
      raise "O arquivo de bairros com latitude e longitude não foi encontrado."
    end      
  end

  def mapa_calor
    if File.exists?("mapa_calor.json")
      mapa = JSON File.read("mapa_calor.json")

      unless params[:parlamentar].nil?
        mapa.delete_if {|x| 
          x['parlamentares'].index(params[:parlamentar].to_i).nil? 
        }
      end

      render json: mapa
    else
      raise "O arquivo de mapa de calor não foi encontrado."
    end  
  end

  def rank_bairro_parlamentar
    if File.exists?("mapa_calor.json")
      mapa = JSON File.read("mapa_calor.json")
      bairros = carregar_bairros

      rank = []

      unless params[:parlamentar].nil?
        bairros.each do |bairro|
          qtd = mapa.count {|x| 
                  !x['parlamentares'].index(params[:parlamentar].to_i).nil? &&
                  x['bairro'] == bairro
                }
          rank.push({id_parlamentar: params[:parlamentar].to_i, bairro: bairro, qtd: qtd})
        end
      end

      render json: rank.sort{|x, y|
        y[:qtd] <=> x[:qtd]
      }
    else
      raise "O arquivo de mapa de calor não foi encontrado."
    end  
  end

  def rank_parlamentar_bairro
    if File.exists?("mapa_calor.json")
      mapa = JSON File.read("mapa_calor.json")

      rank = []

      unless params[:bairro].nil?
        mapa.delete_if {|x| 
          x['bairro'].downcase != params[:bairro].downcase
        }


        parlamentares = Api::V1::ParlamentaresController.todos      
        parlamentares.each do |parlamentar|
          qtd = mapa.count {|x| 
                  !x['parlamentares'].index(parlamentar['id']).nil?
                }
          rank.push({parlamentar: parlamentar, bairro: params[:bairro], qtd: qtd})
        end
      end

      render json: rank.sort{|x, y|
        y[:qtd] <=> x[:qtd]
      }
    else
      raise "O arquivo de mapa de calor não foi encontrado."
    end 
  end

  def mapa_calor_full
    if File.exists?("mapa_calor.json")
      mapa = JSON File.read("mapa_calor.json")

      mapa.each_with_index {|item, index|
        pp index
        url = "http://sagl-api.campinas.sp.leg.br/materias/#{item['id_materia']}"
        materia = RestClient.get(url)
        m = JSON(materia.body)['data']
        mapa[index].merge!({"parlamentares" => m['autores_parlamentares']})
      }

      render json: mapa
    else
      raise "O arquivo de mapa de calor não foi encontrado."
    end  
  end

  private

    def carregar_bairros
      if File.exists?("bairros.json")
        JSON File.read("bairros.json")
      else
        raise "O arquivo de bairros não foi encontrado."
      end      
    end

    def bairros_lat_long_google
      bairros = carregar_bairros
  
      bairros_lat_lng = []
  
      bairros.each do |bairro|
        url = "https://maps.googleapis.com/maps/api/geocode/json?address=#{bairro.accentless.sub(' ', '+')},+Campinas+SP,+Brasil&key=AIzaSyDng7ZHJfijGhKVxvmgO2ngxErVyQ3qccM"
        retorno = JSON RestClient.get(url)
        if retorno['status'] == "OK"
          retorno['results'].each do |geo|
            latitude = geo['geometry']['location']['lat']
            longitude = geo['geometry']['location']['lng']
            if bairros_lat_lng.index(bairro).nil?
              bairros_lat_lng.push({bairro: bairro, latitude: latitude, longitude: longitude})
            end
          end
        end
      end
  
      render json: bairros_lat_lng
    end

end
